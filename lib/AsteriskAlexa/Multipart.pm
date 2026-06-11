package AsteriskAlexa::Multipart;

use strict;
use warnings;

use Email::MIME;
use Exporter qw(import);

our @EXPORT_OK = qw(extract_mpeg_audio);

sub extract_mpeg_audio {
    my ($content_type, $body) = @_;

    defined $content_type && $content_type =~ /^multipart\//i
        or die "response is not multipart\n";
    defined $body
        or die "response body is undefined\n";

    my $message = Email::MIME->new(
        "MIME-Version: 1.0\r\nContent-Type: $content_type\r\n\r\n" . $body
    );
    for my $part ($message->subparts) {
        my $part_type = lc($part->content_type || "");
        return $part->body_raw if $part_type =~ m{^audio/mpeg\b};
    }

    die "response does not contain an audio/mpeg part\n";
}

1;
