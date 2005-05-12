#!/usr/bin/perl
#
# mySociety/Parties.pm:
# Political party definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Parties.pm,v 1.6 2005/05/12 11:54:33 francis Exp $
#

package mySociety::Parties;

use strict;

=head1 NAME

mySociety::Parties

=head1 DESCRIPTION

Definitions relating to Political Parties.  For example, alternative
names for them.

=item %type_name

Map names of parties to their canonical name.

=cut
%mySociety::Parties::canonical = (
    "Conservative" => "Conservative",
    "Con" => "Conservative",
    "Ind Con" => "Independent Conservative",

    "DUP" => "DUP",
    "DU" => "DUP",

    "Green" => "Green",

    "Ind" => "Independent",

    "Labour" => "Labour",
    "Lab" => "Labour",
    "Lab/Co-op" => "Labour / Co-operative",

    "LDem" => "Liberal Democrat",
    "Liberal Democrat" => "Liberal Democrat",

    "PC" => "Plaid Cymru",
    "Plaid Cymru" => "Plaid Cymru",

    "Res" => "Respect",
    "Respect" => "Respect",

    "SDLP" => "SDLP",

    "SNP" => "SNP",

    "SSP" => "SSP",

    # Scottish Senior Citizens United Party
    "SSCUP" => "SSCUP",

    "SPK" => "Speaker",
    "DCWM" => "Deputy Speaker",
    "CWM" => "Deputy Speaker",

    "SF" => "Sinn Féin",
    "Sinn Fein" => "Sinn Féin",

    "UK Independence" => "UK Independence",

    "UU" => "UUP",
    "UUP" => "UUP",

    # Latest Robert Kilroy-Silk vehicle
    "Veritas" => "Veritas",

    # For Democratic Services etc.
    "NOT A PERSON" => "NOT A PERSON"
);

# Ensure that canonical party values are themselves canonical....
foreach (values(%mySociety::Parties::canonical)) {
    $mySociety::Parties::canonical{$_} ||= $_;
}

1;
