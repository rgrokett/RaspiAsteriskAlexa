#!/usr/bin/perl
#
# GET A NEW AWS TOKEN FOR AVS
# $ sudo perl -MCPAN -e 'install JSON'
# $ sudo apt-get install libjson-pp-perl

use JSON qw( decode_json );

# Send POST Request
my $debug = 0;
my $tokenfile = "/tmp/token.avs";
my $request   = "/tmp/token.req";
my $response  = "/tmp/token.resp";
my $url       = "https://api.amazon.com/auth/o2/token";

my $post = "grant_type=refresh_token&refresh_token=YOUR_REFRESH_TOKEN&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" ;

if ($debug) { $verbose = "-v"; }
else { $verbose = ""; }

print ("\nSending HTTP TOKEN REQ to AVS.\n") if ($debug);
my $cmd = qq|/usr/bin/curl -L $verbose -o $response -d "$post" $url\n|;

# just to see request
open($fh, ">", "$request") or die "Can't write file $request: $!";
print $fh "$cmd";
close($fh);

# SEND
$status = `$cmd`;

# READ RESULTS
open(RESULTS, "$response");
$json = do { local $/; <RESULTS> };
close(RESULTS);

# JSON PARSING HERE
$decoded = decode_json($json);
$token = $decoded ->{'access_token'};

# Write out token
open($fh, ">", "$tokenfile") or die "Can't write file $tokenfile: $!";
print $fh "$token";
close($fh);
print ("Token:".$token) if ($debug);

