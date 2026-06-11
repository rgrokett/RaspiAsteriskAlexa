use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir tempfile);
use JSON::PP qw(encode_json);
use Test::More;

my ($fh, $path) = tempfile();
chmod 0640, $path or die "chmod $path: $!";
print {$fh} <<'CONFIG';
client_id=test-client
client_secret=test-secret
refresh_token=test-refresh
cache_dir=/tmp
CONFIG
close $fh or die "close $path: $!";

my $output = qx{$^X token.pl --config "$path" --check-config 2>&1};
is($? >> 8, 0, "valid protected configuration accepted");
like($output, qr/Configuration is valid/, "validation reports success");

chmod 0644, $path or die "chmod $path: $!";
$output = qx{$^X token.pl --config "$path" --check-config 2>&1};
isnt($? >> 8, 0, "world-readable configuration rejected");
like(
    $output,
    qr/must not be accessible by other users/,
    "unsafe permission error is explicit",
);

chmod 0640, $path or die "chmod $path: $!";
open($fh, ">>", $path) or die "open $path: $!";
print {$fh} "oauth_url=http://example.invalid/token\n";
close $fh or die "close $path: $!";
$output = qx{$^X token.pl --config "$path" --check-config 2>&1};
isnt($? >> 8, 0, "non-TLS OAuth URL rejected");
like($output, qr/oauth_url must use HTTPS/, "TLS validation is explicit");

my $cache_dir = tempdir(CLEANUP => 1);
my $cache_path = File::Spec->catfile($cache_dir, "token.json");
open(my $cache_fh, ">", $cache_path) or die "open $cache_path: $!";
print {$cache_fh} encode_json({
    access_token => "cached-test-token",
    expires_at   => time + 3600,
});
close $cache_fh or die "close $cache_path: $!";
chmod 0600, $cache_path or die "chmod $cache_path: $!";

my ($cache_config_fh, $cache_config_path) = tempfile();
chmod 0640, $cache_config_path or die "chmod $cache_config_path: $!";
print {$cache_config_fh} <<"CONFIG";
client_id=test-client
client_secret=test-secret
refresh_token=test-refresh
cache_dir=$cache_dir
oauth_url=https://example.invalid/token
CONFIG
close $cache_config_fh or die "close $cache_config_path: $!";

$output = qx{$^X token.pl --config "$cache_config_path" --print-token 2>&1};
is($? >> 8, 0, "unexpired cached token returned without OAuth request");
is($output, "cached-test-token\n", "cached token output is exact");

done_testing;
