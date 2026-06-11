use strict;
use warnings;

use JSON::PP qw(decode_json);
use Test::More;

my @checks = (
    [ [ $^X, "-Ilib", "-c", "lib/AsteriskAlexa/Multipart.pm" ], "MIME parser compiles" ],
    [ [ $^X, "-c", "alexa.agi" ], "alexa.agi compiles" ],
    [ [ $^X, "-c", "token.pl" ], "token.pl compiles" ],
    [ [ "bash", "-n", "install.sh" ], "install.sh syntax" ],
    [ [ "bash", "-n", "grant_token.sh" ], "grant_token.sh syntax" ],
);

for my $check (@checks) {
    my ($command, $description) = @{$check};
    system @{$command};
    is($? >> 8, 0, $description);
}

{
    open(my $fh, "<", "avs_audio.json")
        or die "open avs_audio.json: $!";
    local $/;
    my $metadata = eval { decode_json(<$fh>) };
    ok(ref $metadata eq "HASH", "AVS metadata is valid JSON");
}

done_testing;
