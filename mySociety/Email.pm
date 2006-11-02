#!/usr/bin/perl
#
# mySociety/Email.pm:
# Email utilities.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Email.pm,v 1.13 2006/11/02 12:23:59 matthew Exp $
#

package mySociety::Email::Error;

use Error qw(:try);

@mySociety::Email::Error::ISA = qw(Error::Simple);

package mySociety::Email;

use strict;

use Encode;
use Encode::Byte;   # iso-8859-* etc.
use Error qw(:try);
use MIME::QuotedPrint;
use POSIX qw();
use Text::Wrap qw();

=item encode_string STRING

Attempt to encode STRING in the least challenging of a variety of possible
encodings. Returns a list giving the IANA name for the selected encoding and a
byte string of the encoded text.

=cut
sub encode_string ($) {
    my $s = shift;
    die "STRING is not valid ASCII/UTF-8" unless (utf8::valid($s));

    foreach my $encoding (qw(
                    us-ascii
                    iso-8859-1
                    iso-8859-15
                    windows-1252
                    utf-8
                )) {
        my $octets;
        eval {
            $octets = encode($encoding, $s, Encode::FB_CROAK);
        };
        return ($encoding, $octets) if ($octets);
    }

    die "Unable to encode STRING in any supported encoding (shouldn't happen)";
}

=item format_mimewords STRING

Return STRING, formatted for inclusion in an email header.

=cut
sub format_mimewords ($) {
    my ($text) = @_;
    
    my ($encoding, $octets) = encode_string($text);
    if ($encoding eq 'us-ascii') {
        return $text;
    } else {
        # This is unpleasant. Whitespace which separates two encoded-words is
        # not significant, so we need to fold it in to one of them. Rather than
        # having some complicated state-machine driven by words, just encode
        # the whole line if it contains any non-ASCII characters. However, this
        # is going to suck whatever happens, because we can't include a blank
        # in a quoted-printable MIME-word, so we have to encode it as =20 or
        # whatever, so this is still going to be near-unreadable for users
        # whose MUAs suck at MIME.
        #
        # We also encode characters which are ASCII but are not valid in
        # atoms in RFC 2822 (see below in format_email_address), so that we
        # avoid having to encode *and* quote a real name in an email address.
        # Again this means we encode more characters than we need to, but
        # that's life.
        $octets =~ s#(\s|[\x00-\x1f\x7f-\xff"\$%'(),.:;<>@\[\]\\])#sprintf('=%02x', ord($1))#ge;
        $octets = "=?$encoding?Q?$octets?=";
        utf8::decode($octets);
        return $octets;
    }
}

=item format_email_address NAME ADDRESS

Return a suitably MIME-encoded version of "NAME <ADDRESS>" suitable for use in
an email From:/To: header.

=cut
sub format_email_address ($$) {
    my ($name, $addr) = @_;

    # 
    # The "display-name" part of the mailbox is a "phrase", meaning one or more
    # atoms or quoted-strings. Atoms consist of atext:
    # 
    # atext           =       ALPHA / DIGIT / ; Any character except controls,
    #                         "!" / "#" /     ;  SP, and specials.
    #                         "$" / "%" /     ;  Used for atoms
    #                         "&" / "'" /
    #                         "*" / "+" /
    #                         "-" / "/" /
    #                         "=" / "?" /
    #                         "^" / "_" /
    #                         "`" / "{" /
    #                         "|" / "}" /
    #                         "~"
    #
    
    # First format name for any non-ASCII characters, if necessary.
    $name = format_mimewords($name);

    # Now decide whether it is to be formatted as an atom or a quoted-string.
    if ($name =~ /[^A-Za-z0-9!#\$%&'*+\-\/=?^_`{|}~]/) {
        # Contains characters which aren't valid in atoms, so make a
        # quoted-pair instead.
        $name =~ s/["\\]/\\$1/g;
        $name = qq("$name");
    }
    return sprintf('%s <%s>', $name, $addr);
}

# do_one_substitution PARAMS NAME
# If NAME is not present in PARAMS, throw an error; otherwise return the value
# of the relevant parameter.
sub do_one_substitution ($$) {
    my ($p, $n) = @_;
    throw mySociety::Email::Error("Substitution parameter '$n' is not present")
        unless (exists($p->{$n}));
    throw mySociety::Email::Error("Substitution parameter '$n' is not defined")
        unless (defined($p->{$n}));
    return $p->{$n};
}

=item do_template_substitution TEMPLATE PARAMETERS

Given the text of a TEMPLATE and a reference to a hash of PARAMETERS, return in
list context the subject and body of the email. This operates on and returns
Unicode strings.

=cut
sub do_template_substitution ($$) {
    my ($body, $params) = @_;
    $body =~ s#<\?=\$values\['([^']+)'\]\?>#do_one_substitution($params, $1)#ges;

    my $subject;
    if ($body =~ m#^Subject: ([^\n]*)\n\n#s) {
        $subject = $1;
        $body =~ s#^Subject: ([^\n]*)\n\n##s;
    }

    $body  =~ s/\r\n/\n/gs;

    # Merge paragraphs into their own line.  Two blank lines separate a
    # paragraph.

    # regex means, "replace any line ending that is neither preceded (?<!\n)
    # nor followed (?![ \t]*\n) by a blank line with a single space".
    $body =~ s#(?<!\n)[ \t]*\n(?![ \t]*\n)# #gs;

    # Wrap text to 72-column lines.
    local($Text::Wrap::columns = 69);
    local($Text::Wrap::huge = 'overflow');
    local($Text::Wrap::unexpand = 0);
    my $wrapped = Text::Wrap::wrap('     ', '     ', $body);
    $wrapped =~ s/^\s+$//mg;

    return ($subject, $wrapped);
}

=item construct_email SPEC

Construct an email message according to SPEC, which is an associative array
containing elements as given below. Returns an on-the-wire email (though with
"\n" line-endings).

=over 4

=item _body_

Text of the message to send, as a UTF-8 string with "\n" line-endings.

=item _unwrapped_body_

Text of the message to send, as a UTF-8 string with "\n" line-endings. It will
be word-wrapped before sending.

=item _template_, _parameters_

Templated body text and an associative array of template parameters. _template
contains optional substititutions <?=$values['name']?>, each of which is
replaced by the value of the corresponding named value in _parameters_. It is
an error to use a substitution when the corresponding parameter is not present
or undefined. The first line of the template will be interpreted as contents of
the Subject: header of the mail if it begins with the literal string 'Subject:
' followed by a blank line. The templated text will be word-wrapped to produce
lines of appropriate length.

=item To

Contents of the To: header, as a literal UTF-8 string or an array of addresses
or [address, name] pairs.

=item From

Contents of the From: header, as an email address or an [address, name] pair.

=item Cc

Contents of the Cc: header, as for To.

=item Subject

Contents of the Subject: header, as a UTF-8 string.

=item I<any other element>

interpreted as the literal value of a header with the same name.

=back

If no Date is given, the current date is used. If no To is given, then the
string "Undisclosed-Recipients: ;" is used. It is an error to fail to give a
body, unwrapped body or a templated body; or From or Subject.

=cut
sub construct_email ($) {
    my $p = shift;

    if (!exists($p->{_body_}) && !exists($p->{_unwrapped_body_})
        && (!exists($p->{_template_}) || !exists($p->{_parameters_}))) {
        throw mySociety::Email::Error("Must specify field '_body_' or '_unwrapped_body_', or both '_template_' and '_parameters_'");
    }

    if (exists($p->{_unwrapped_body_})) {
        throw mySociety::Email::Error("Fields '_body_' and '_unwrapped_body_' both specified") if (exists($p->{_body_}));
        my $t = $p->{_unwrapped_body_};
        $t =~ s/\r\n/\n/gs;
        local($Text::Wrap::columns = 69);
        local($Text::Wrap::huge = 'overflow');
        local($Text::Wrap::unexpand = 0);
        $p->{_body_} = Text::Wrap::wrap('     ', '     ', $t);
        $p->{_body_} =~ s/^\s+$//mg;
        delete($p->{_unwrapped_body_});
    }

    if (exists($p->{_template_})) {
        throw mySociety::Email::Error("Template parameters '_parameters_' must be an associative array")
            if (ref($p->{_parameters_}) ne 'HASH');
        
        (my $subject, $p->{_body_}) = mySociety::Email::do_template_substitution($p->{_template_}, $p->{_parameters_});
        delete($p->{_template_});
        delete($p->{_parameters_});

        $p->{Subject} = $subject if (defined($subject));
    }

    throw mySociety::Email::Error("missing field 'Subject' in MESSAGE") if (!exists($p->{Subject}));
    throw mySociety::Email::Error("missing field 'From' in MESSAGE") if (!exists($p->{From}));

    my %hdr;
    $hdr{Subject} = mySociety::Email::format_mimewords($p->{Subject});

    # To: and Cc: are address-lists.
    foreach (qw(To Cc)) {
        next unless (exists($p->{$_}));

        if (ref($p->{$_}) eq '') {
            # Interpret as a literal string in UTF-8, so all we need to do is
            # escape it.
            $hdr{$_} = mySociety::Email::format_mimewords($p->{$_});
        } elsif (ref($p->{$_}) eq 'ARRAY') {
            # Array of addresses or [address, name] pairs.
            my @a = ( );
            foreach (@{$p->{$_}}) {
                if (ref($_) eq '') {
                    push(@a, $_);
                } elsif (ref($_) ne 'ARRAY' || @$_ != 2) {
                    throw mySociety::Email::Error("Element of '$_' field should be string or 2-element array");
                } else {
                    push(@a, mySociety::Email::format_email_address($_->[1], $_->[0]));
                }
            }
            $hdr{$_} = join(', ', @a);
        } else {
            throw mySociety::Email::Error("Field '$_' in MESSAGE should be single value or an array");
        }
    }

    if (exists($p->{From})) {
        if (ref($p->{From}) eq '') {
            $hdr{From} = $p->{From}; # XXX check syntax?
        } elsif (ref($p->{From}) ne 'ARRAY' || @{$p->{From}} != 2) {
            throw mySociety::Email::Error("'From' field should be string or 2-element array");
        } else {
            $hdr{From} = mySociety::Email::format_email_address($p->{From}->[1], $p->{From}->[0]);
        }
    }

    # Some defaults
    $hdr{To} ||= 'Undisclosed-recipients: ;';
    $hdr{Date} ||= POSIX::strftime("%a, %d %h %Y %T %z", localtime(time()));

    foreach (keys(%$p)) {
        $hdr{$_} = $p->{$_} if ($_ !~ /^_/ && !exists($hdr{$_}));
    }

    my ($enc, $bodytext) = encode_string($p->{_body_});
    $hdr{'MIME-Version'} = '1.0';
    $hdr{'Content-Type'} = "text/plain; charset=\"$enc\"";

    my $encoded_body;
    if ($enc eq 'us-ascii') {
        $hdr{'Content-Transfer-Encoding'} = '7bit';
        $encoded_body = $bodytext;
    } else {
        $hdr{'Content-Transfer-Encoding'} = 'quoted-printable';
        $encoded_body = encode_qp($bodytext, "\n");
    }

    my $text = '';
    foreach (keys %hdr) {
        # No caller should introduce a header with a linebreak in it, but just
        # in case they do, strip them out.
        my $h = $hdr{$_};
        $h =~ s/\r?\n/ /gs;
        $text .= "$_: $h\n";
    }

    $text .= "\n" . $encoded_body . "\n\n";
    return $text;
}


1;
