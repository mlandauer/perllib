#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Util.pm,v 1.1 2004/10/05 16:42:02 chris Exp $
#

package mySociety::Util;

use strict;
use Error qw(:try);
use IO::File;
use Fcntl;

=item random_bytes NUMBER

Return the given NUMBER of random bytes from /dev/random.

=cut
sub random_bytes ($) {
    my ($count) = @_;

    no utf8;

    our $f;
    if (!$f) {
        $f = new IO::File("/dev/random", O_RDONLY) or die "/dev/random: $!";
    }

    my $l = '';

    while (length($l) < $count) {
        $f->sysread($l, $count - length($l), length($l)) or die "/dev/random: $!";
    }

    return $l;
}

=item named_tempfile [SUFFIX]

Return in list context an IO::Handle open on a temporary file, and the name of
that file. If specified, SUFFIX a suffix which will be appended to the filename
(include any leading dot if you want to create, e.g., files called "foo.html"
or whatever).

=cut
sub named_tempfile (;$) {
    my ($suffix) = @_;
    $suffix ||= '';
    my ($where) = grep { -d $_ and -w $_ } ($ENV{TEMP}, $ENV{TMPDIR}, $ENV{TEMPDIR}, "/tmp");
    die "no temporary directory available (last tried was \"$where\", error was $!)" unless (defined($where));
    
    my $prefix = $0;
    $prefix =~ s#^.*/##;
    my $name;
    for (my $i = 0; $i < 10; ++$i) {
        $name = sprintf('%s/%s-temp-%08x-%08x%s', $where, $prefix, int(rand(0xffffffff)), int(rand(0xffffffff)), $suffix);
        if (my $h = new IO::File($name, O_WRONLY | O_CREAT | O_EXCL, 0600)) {
            return ($h, $name);
        }
    }

    die "unable to create temporary file; last attempted name was \"$name\" and open failed with error $!";
}

1;
