use strict;
use warnings;

use lib "lib";

use AsteriskAlexa::Multipart qw(extract_mpeg_audio);
use Test::More;

my $boundary = "test-boundary";
my $audio = "\x49\x44\x33\x00\xff\x10binary-audio";
my $body
    = "--$boundary\r\n"
    . "Content-Type: application/json\r\n\r\n"
    . qq|{"directive":"test"}\r\n|
    . "--$boundary\r\n"
    . "Content-Type: audio/mpeg\r\n"
    . "Content-ID: <audio-item>\r\n\r\n"
    . $audio
    . "\r\n--$boundary--\r\n";

is(
    extract_mpeg_audio(qq{multipart/related; boundary="$boundary"}, $body),
    $audio,
    "binary MPEG part is extracted without multipart framing",
);

eval { extract_mpeg_audio("application/json", "{}") };
like($@, qr/not multipart/, "non-multipart response is rejected");

done_testing;
