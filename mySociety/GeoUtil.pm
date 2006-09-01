#!/usr/bin/perl
#
# mySociety/GeoUtil.pm:
# Various miscellaneous geography related routines.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: GeoUtil.pm,v 1.3 2006/09/01 17:22:30 francis Exp $
#

package mySociety::GeoUtil;

use strict;

use Geo::HelmertTransform;
use Geography::NationalGrid;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&national_grid_to_wgs84);
}
our @EXPORT_OK;

=item national_grid_to_wgs84 EASTING NORTHING COORDSYST

Converts a coordinate in UK EASTING and NORTHING to WGS84.
COORDSYST can be either 'G' for Great Britain coordinate system, or 'I' for
Northern Ireland.  The latitude and longitude are the return values.
=cut
sub national_grid_to_wgs84($$$) {
    my ($easting, $northing, $coordsyst) = @_;

    our ($wgs84, $airy1830, $airy1830m);
    $wgs84      ||= Geo::HelmertTransform::datum("WGS84");
    $airy1830   ||= Geo::HelmertTransform::datum("Airy1830");
    $airy1830m  ||= Geo::HelmertTransform::datum("Airy1830Modified");

    my ($lat, $lon, $d);

    if ($coordsyst eq 'G') {
        my $p = new Geography::NationalGrid('GB', Easting => $easting, Northing => $northing);
        $lat = $p->latitude();
        $lon = $p->longitude();
        $d = $airy1830;
    } elsif ($coordsyst eq 'I') {
        my $p = new Geography::NationalGrid('IE', Easting => $easting, Northing => $northing);
        $lat = $p->latitude();
        $lon = $p->longitude();
        $d = $airy1830m;
    } else {
        die "bad value '$coordsyst' for coordinate system in nationalgrid_to_wgs84";
    }
    return Geo::HelmertTransform::convert_datum($d, $wgs84, $lat, $lon, 0); # 0 is altitude
}

=item wgs84_to_national_grid LATITUDE LONGITUDE COORDSYST

Converts a coordinate in WGS84 LATITUDE and LONGITUDE to UK grid coordinate.
COORDSYST can be either 'G' for Great Britain coordinate system, or 'I' for
Northern Ireland.  The easting and northing are the return values.
=cut
sub wgs84_to_national_grid($$$) {
    my ($lat, $lon, $coordsyst) = @_;

    our ($wgs84, $airy1830, $airy1830m);
    $wgs84      ||= Geo::HelmertTransform::datum("WGS84");
    $airy1830   ||= Geo::HelmertTransform::datum("Airy1830");
    $airy1830m  ||= Geo::HelmertTransform::datum("Airy1830Modified");

    my ($easting, $northing, $d);

    if ($coordsyst eq 'G') {
        $d = $airy1830;
    } elsif ($coordsyst eq 'I') {
        $d = $airy1830m;
    } else {
        die "bad value '$coordsyst' for coordinate system in nationalgrid_to_wgs84";
    }
    my $height;
    ($lat, $lon, $height) = Geo::HelmertTransform::convert_datum($wgs84, $d, $lat, $lon, 0); # 0 is altitude

    my $p;
    if ($coordsyst eq 'G') {
        $p = new Geography::NationalGrid('GB', Latitude => $lat, Longitude => $lon);
    } elsif ($coordsyst eq 'I') {
        $p = new Geography::NationalGrid('IE', Latitude => $lat, Longitude => $lon);
    } else {
        die "bad value '$coordsyst' for coordinate system in nationalgrid_to_wgs84";
    }
    return ($p->easting, $p->northing);
}

11;
