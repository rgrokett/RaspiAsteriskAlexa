#!/usr/bin/env perl

use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempfile);
use Getopt::Long qw(GetOptions);
use HTTP::Tiny;
use JSON::PP qw(decode_json encode_json);
use POSIX qw(strftime);
use URI::Escape qw(uri_escape_utf8);

my $config_file = $ENV{ALEXA_CONFIG} || "/etc/asterisk/alexa.conf";
my $print_token = 0;
my $force_refresh = 0;
my $check_config = 0;
my $exchange_code = 0;

GetOptions(
    "config=s"       => \$config_file,
    "print-token"    => \$print_token,
    "force-refresh"  => \$force_refresh,
    "check-config"   => \$check_config,
    "exchange-code"   => \$exchange_code,
) or usage();

usage() if @ARGV;

my $config = read_config($config_file);
validate_config($config, $exchange_code ? 0 : 1);

if ($check_config) {
    print "Configuration is valid: $config_file\n";
    exit 0;
}

if ($exchange_code) {
    my $code = <STDIN>;
    defined $code or die "Authorization code was not provided on standard input.\n";
    chomp $code;
    exchange_authorization_code($config, $code, $config_file);
    exit 0;
}

my $cache_dir = $config->{cache_dir} || "/var/cache/asterisk-alexa";
my $cache_file = File::Spec->catfile($cache_dir, "token.json");
my $lock_file = File::Spec->catfile($cache_dir, "token.lock");

-d $cache_dir
    or die "Token cache directory does not exist: $cache_dir\n";

sysopen(my $lock_fh, $lock_file, O_WRONLY | O_CREAT, 0600)
    or die "Cannot open token lock $lock_file: $!\n";
flock($lock_fh, LOCK_EX)
    or die "Cannot lock $lock_file: $!\n";

my $cached = read_token_cache($cache_file);
my $now = time;
my $refresh_margin = $config->{refresh_margin_seconds} // 300;

if (
    !$force_refresh
    && $cached->{access_token}
    && ($cached->{expires_at} // 0) > $now + $refresh_margin
) {
    print "$cached->{access_token}\n" if $print_token;
    exit 0;
}

my $response = oauth_request(
    $config,
    {
        grant_type    => "refresh_token",
        refresh_token => $config->{refresh_token},
        client_id     => $config->{client_id},
        client_secret => $config->{client_secret},
    },
);

my $expires_in = $response->{expires_in};
$expires_in = 3600 unless defined $expires_in && $expires_in =~ /^\d+$/;

my $cache = {
    access_token => required_response_value($response, "access_token"),
    expires_at   => $now + $expires_in,
    token_type   => $response->{token_type} || "bearer",
    updated_at   => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($now)),
};

write_json_atomic($cache_file, $cache, 0600);
print "$cache->{access_token}\n" if $print_token;

sub exchange_authorization_code {
    my ($settings, $code, $path) = @_;

    length $code or die "Authorization code cannot be empty.\n";

    my $response = oauth_request(
        $settings,
        {
            grant_type    => "authorization_code",
            code          => $code,
            client_id     => $settings->{client_id},
            client_secret => $settings->{client_secret},
            redirect_uri  => $settings->{redirect_uri} || "https://localhost",
        },
    );

    $settings->{refresh_token}
        = required_response_value($response, "refresh_token");
    write_config_atomic($path, $settings);
    print "Refresh token stored in $path\n";
}

sub oauth_request {
    my ($settings, $fields) = @_;

    my $body = join "&", map {
        uri_escape_utf8($_) . "=" . uri_escape_utf8($fields->{$_})
    } sort keys %{$fields};

    my $http = HTTP::Tiny->new(
        timeout    => $settings->{http_timeout_seconds} || 20,
        verify_SSL => 1,
        max_redirect => 0,
        agent      => "RaspiAsteriskAlexa/2",
    );

    my $response = $http->post(
        $settings->{oauth_url} || "https://api.amazon.com/auth/o2/token",
        {
            headers => {
                "content-type" => "application/x-www-form-urlencoded",
                "accept"       => "application/json",
            },
            content => $body,
        },
    );

    my $decoded = eval { decode_json($response->{content} || "") };
    if (!$response->{success}) {
        my $detail
            = ref $decoded eq "HASH"
            ? ($decoded->{error_description} || $decoded->{error} || "")
            : "";
        die sprintf(
            "OAuth request failed: HTTP %s %s%s\n",
            $response->{status} || "unknown",
            $response->{reason} || "",
            $detail ? " ($detail)" : "",
        );
    }

    ref $decoded eq "HASH"
        or die "OAuth response was not a JSON object.\n";
    return $decoded;
}

sub read_config {
    my ($path) = @_;

    -l $path and die "Configuration must not be a symbolic link: $path\n";
    my @stat = stat $path;
    @stat or die "Cannot stat configuration $path: $!\n";
    -f _ or die "Configuration is not a regular file: $path\n";
    ($stat[2] & 0007) == 0
        or die "Configuration must not be accessible by other users: $path\n";

    open(my $fh, "<", $path)
        or die "Cannot read configuration $path: $!\n";

    my %settings;
    my $line_number = 0;
    while (my $line = <$fh>) {
        $line_number++;
        chomp $line;
        $line =~ s/\r$//;
        next if $line =~ /^\s*(?:#|$)/;
        $line =~ /^([A-Za-z][A-Za-z0-9_]*)=(.*)$/
            or die "Invalid configuration at $path line $line_number.\n";
        my ($key, $value) = ($1, $2);
        $value =~ s/^\s+|\s+$//g;
        $settings{$key} = $value;
    }
    close $fh or die "Cannot close configuration $path: $!\n";

    return \%settings;
}

sub validate_config {
    my ($settings, $require_refresh_token) = @_;

    for my $key (qw(client_id client_secret)) {
        length($settings->{$key} // "")
            or die "Missing required configuration value: $key\n";
    }
    if ($require_refresh_token) {
        length($settings->{refresh_token} // "")
            or die "Missing required configuration value: refresh_token\n";
    }

    for my $key (qw(oauth_url avs_url)) {
        next unless length($settings->{$key} // "");
        $settings->{$key} =~ m{\Ahttps://}i
            or die "$key must use HTTPS.\n";
    }
    for my $key (qw(http_timeout_seconds refresh_margin_seconds)) {
        next unless length($settings->{$key} // "");
        $settings->{$key} =~ /^\d+$/
            or die "$key must be a non-negative integer.\n";
    }
}

sub read_token_cache {
    my ($path) = @_;
    return {} unless -e $path;

    open(my $fh, "<", $path)
        or die "Cannot read token cache $path: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh or die "Cannot close token cache $path: $!\n";

    my $decoded = eval { decode_json($content) };
    return ref $decoded eq "HASH" ? $decoded : {};
}

sub write_json_atomic {
    my ($path, $value, $mode) = @_;
    my $directory = dirname($path);
    my ($fh, $temporary) = tempfile(".token-XXXXXX", DIR => $directory);
    chmod $mode, $temporary
        or die "Cannot set permissions on $temporary: $!\n";
    print {$fh} encode_json($value), "\n"
        or die "Cannot write $temporary: $!\n";
    close $fh or die "Cannot close $temporary: $!\n";
    rename $temporary, $path
        or die "Cannot replace $path: $!\n";
}

sub write_config_atomic {
    my ($path, $settings) = @_;
    my @existing = stat $path;
    @existing or die "Cannot stat configuration $path: $!\n";
    my $directory = dirname($path);
    my ($fh, $temporary) = tempfile(".alexa-conf-XXXXXX", DIR => $directory);
    chmod 0640, $temporary
        or die "Cannot set permissions on $temporary: $!\n";
    chown $existing[4], $existing[5], $temporary
        or die "Cannot preserve ownership on $temporary: $!\n";

    print {$fh} "# Generated by token.pl --exchange-code\n";
    for my $key (sort keys %{$settings}) {
        my $value = $settings->{$key};
        defined $value or next;
        $value !~ /[\r\n]/
            or die "Configuration value $key contains a newline.\n";
        print {$fh} "$key=$value\n";
    }

    close $fh or die "Cannot close $temporary: $!\n";
    rename $temporary, $path
        or die "Cannot replace $path: $!\n";
}

sub required_response_value {
    my ($response, $key) = @_;
    length($response->{$key} // "")
        or die "OAuth response did not include $key.\n";
    return $response->{$key};
}

sub usage {
    die <<'USAGE';
Usage:
  token.pl [--config FILE] [--print-token] [--force-refresh]
  token.pl [--config FILE] --check-config
  printf '%s\n' AUTHORIZATION_CODE | token.pl [--config FILE] --exchange-code
USAGE
}
