use v5.32.0;
use warnings;
use experimental 'signatures';

package Huell::Util;

use Sub::Exporter -setup => [ qw(rgb_to_xy) ];

sub rgb_to_xy ($r_i, $g_i, $b_i) {
  sub enh_color ($norm) {
    return $norm / 12.92 if $norm <= 0.04045;

    my $enh = (($norm + 0.055) / (1.0 + 0.055)) ** 2.4;
    return $enh;
  }

  my $r = enh_color($r_i / 255);
  my $g = enh_color($g_i / 255);
  my $b = enh_color($b_i / 255);

  my $x = $r * 0.649926 + $g * 0.103455 + $b * 0.197109;
  my $y = $r * 0.234327 + $g * 0.743075 + $b * 0.022598;
  my $z = $r * 0.000000 + $g * 0.053077 + $b * 1.035763;

  return [ 0, 0 ] if $x + $y + $z == 0;

  my $xy_x = $x / ($x + $y + $z);
  my $xy_y = $y / ($x + $y + $z);

  return [ $xy_x, $xy_y ];
}

1;
