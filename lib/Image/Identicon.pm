## ----------------------------------------------------------------------------
#  Image::Identicon.
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright 2007 YAMASHINA Hio
# -----------------------------------------------------------------------------
# $Id$
# -----------------------------------------------------------------------------
package Image::Identicon;

use strict;
use warnings;

use GD;
use GD::Polyline;
use Digest::SHA qw(sha1);

our $VERSION = '0.01';

our $DEBUG = 0;

our $PATCHES = [
	[ 0, 4, 24, 20, 0,              ], # 0
	[ 0, 4, 20, 0,                  ], # 1
	[ 2, 24, 20, 2,                 ], # 2
	[ 0, 2, 22, 20, 0,              ], # 3
	[ 2, 14, 22, 10, 2,             ], # 4
	[ 0, 14, 24, 22, 0,             ], # 5
	[ 2, 24, 22, 13, 11, 22, 20, 2, ], # 6
	[ 0, 14, 22, 0,                 ], # 7
	[ 6, 8, 18, 16, 6,              ], # 8
	[ 4, 20, 10, 12, 2, 4,          ], # 9
	[ 0, 2, 12, 10, 0,              ], # 10
	[ 10, 14, 22, 10,               ], # 11
	[ 20, 12, 24, 20,               ], # 12
	[ 10, 2, 12, 10,                ], # 12
	[ 0, 2, 10, 0,                  ], # 14
	[                               ], # 15
];

our $PATCH_SYMMETRIC = 1;
our $PATCH_INVERTED  = 2;

our $PATCH_FLAGS = [
	$PATCH_SYMMETRIC, 0, 0, 0,
	$PATCH_SYMMETRIC, 0, 0, 0,
	$PATCH_SYMMETRIC, 0, 0, 0, 0, 0, 0,
	$PATCH_SYMMETRIC + $PATCH_INVERTED ];

our $CENTER_PATCHES = [ 0, 4, 8, 15, ];

1;

# -----------------------------------------------------------------------------
# Image::Indenticon->new(salt=>$salt);
# 
sub new
{
	my $pkg = shift;
	my $opts = @_ && ref($_[0]) ? shift : {@_};
	my $this = {};
	$this->{salt} = $opts->{salt};
	$this->{salt} or die "no salt";
	bless $this, $pkg;
}

# -----------------------------------------------------------------------------
# my $code = $obj->identicon_code();
# my $code = $obj->identicon_code($addr);
#  calc 32bit identicon code from ip address.
# 
sub identicon_code
{
	my $this = shift;
	my $addr = shift || $ENV{REMOTE_ADDR} || '0.0.0.0';
	
	$this->{salt} or die "isalt must be set prior to retrieving identicon code";
	my @ip = $addr =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
	my $packed = pack("C*", @ip);
	join('.', unpack("C*",$packed)) eq $addr or die "invalid ip addr: $addr";
	
	my $ipint = unpack("N", $packed);
	my $code  = unpack("N", sha1("$ipint+$this->{salt}"));
	$code;
}

# -----------------------------------------------------------------------------
# my $result = $obj->identicon_code();
# my $result = $obj->identicon_code($code);
#  render image.
#  returns GD::Image through $result->{image}.
# 
sub render
{
	my $this = shift;
	my $code  = shift || $this->identicon_code;
	my $scale = shift || 10;

	#  decode the code into parts
	#  bit 0-1: middle patch type
	#  bit 2: middle invert
	#  bit 3-6: corner patch type
	#  bit 7: corner invert
	#  bit 8-9: corner turns
	#  bit 10-13: side patch type
	#  bit 14: side invert
	#  bit 15: corner turns
	#  bit 16-20: blue color component
	#  bit 21-26: green color component
	#  bit 27-31: red color component
	my $middleType   = $CENTER_PATCHES->[$code & 0x3];
	my $middleInvert = (($code >>  2) & 0x01) != 0;
	my $cornerType   = (($code >>  3) & 0x0f);
	my $cornerInvert = (($code >>  7) & 0x01) != 0;
	my $cornerTurn   = (($code >>  8) & 0x03);
	my $sideType     = (($code >> 10) & 0x0f);
	my $sideInvert   = (($code >> 14) & 0x01) != 0;
	my $sideTurn     = (($code >> 15) & 0x03);
	my $blue  = (($code >> 16) & 0x01f)<<3;
	my $green = (($code >> 21) & 0x01f)<<3;
	my $red   = (($code >> 27) & 0x01f)<<3;
	
	if( $DEBUG )
	{
		print "(r,g,b) = ($red, $green, $blue)\n";
	}
	
	my $patch_size = 5;
	my $source_size = $patch_size * 3 * $scale;
	my $image = new GD::Image($source_size, $source_size, 1);
	
	# color components are used at top of the range for color difference
	# use white background for now.
	# TODO: support transparency.
	my $fore_color = $image->colorAllocate($red, $green, $blue);
	my $back_color = $image->colorAllocate(255,255,255);
	$image->transparent($back_color);

	# outline shapes with a noticeable color (complementary will do) if
	# shape color and background color are too similar (measured by color
	# distance).
	my $stroke_color = undef;
	{
		my $dr = $red-255;
		my $dg = $green-255;
		my $db = $blue-255;
		my $distance = sqrt($dr**2 + $dg**2 + $db**2);
		if( $distance < 32.0 )
		{
			$stroke_color = $image->colorAllocate($red^255, $green^255, $blue^255);
		}
	}
	
	# -------------------------------------------------
	# RENDER AT SOURCE SIZE
	#
	my $r = Image::Identicon::Render->new({
		image => $image,
		patch_size => $patch_size,
		scale      => $scale,
		fore_color => $fore_color,
		back_color => $back_color,
		stroke_color => $stroke_color,
		red   => $red,
		green => $green,
		blue  => $blue,
	});

	# middle patch
	$DEBUG and print "[middle]\n";
	$r->draw({ x=>1, y=>1, patch=>$middleType, turn=>0, invert=>$middleInvert});
	
	# side patchs, starting from top and moving clock-wise
	$DEBUG and print "[sides]\n";
	$r->draw({ x=>1, y=>0, patch=>$sideType, turn=>$sideTurn++, invert=>$sideInvert});
	$r->draw({ x=>2, y=>1, patch=>$sideType, turn=>$sideTurn++, invert=>$sideInvert});
	$r->draw({ x=>1, y=>2, patch=>$sideType, turn=>$sideTurn++, invert=>$sideInvert});
	$r->draw({ x=>0, y=>1, patch=>$sideType, turn=>$sideTurn++, invert=>$sideInvert});

	# corner patchs, starting from top left and moving clock-wise
	$DEBUG and print "[corderes]\n";
	$r->draw({ x=>0, y=>0, patch=>$cornerType, turn=>$cornerTurn++, invert=>$cornerInvert});
	$r->draw({ x=>2, y=>0, patch=>$cornerType, turn=>$cornerTurn++, invert=>$cornerInvert});
	$r->draw({ x=>2, y=>2, patch=>$cornerType, turn=>$cornerTurn++, invert=>$cornerInvert});
	$r->draw({ x=>0, y=>2, patch=>$cornerType, turn=>$cornerTurn++, invert=>$cornerInvert});

	return $r;
}

# -----------------------------------------------------------------------------
# Renderer.
#
package Image::Identicon::Render;
BEGIN{ *DEBUG = \$Image::Identicon::DEBUG }
1;

sub new
{
	my $pkg = shift;
	my $opts = shift;
	bless {%$opts}, $pkg;
}

sub draw
{
	my $r = shift;
	my $opts = ref($_[0])?shift:{@_};
	
	my $image = $r->{image};
	my $patch_size = $r->{patch_size};
	my $scale      = $r->{scale};
	my $fore   = $r->{fore_color};
	my $back   = $r->{back_color};
	my $stroke = $r->{stroke_color};
	
	my $x = $opts->{x};
	my $y = $opts->{y};
	my $patch  = $opts->{patch};
	my $turn   = $opts->{turn};
	my $invert = $opts->{invert};
	
	$patch>=0 or die "\$patch >= 0 failed, got $patch";
	$turn >=0 or die "\$turn >= 0 failed, got $turn";
	
	$x *= $r->{patch_size} * $scale;
	$y *= $r->{patch_size} * $scale;
	$patch %= @$PATCHES;
	$turn %= 4;
	if( ($PATCH_FLAGS->[$patch] & $PATCH_INVERTED) != 0 )
	{
		$invert = !$invert;
	}
	$invert and ($fore, $back) = ($back, $fore);

	$DEBUG and print "(x,y) = ($x, $y)\n";
	$DEBUG and print "(patch, turn, invert) = ($patch, $turn, $invert)\n";
	
	# paint background
	$image->filledRectangle($x, $y, $x+$patch_size*$scale, $y+$patch_size*$scale, $back);
	
	# polything.
	$DEBUG and print "- poly\n";
	my $pl = GD::Polyline->new();
	foreach my $pt (@{$PATCHES->[$patch]})
	{
		my $dx = $pt % 5;
		my $dy = int( $pt / 5 );
		
		# GD::Polyline has rotate(), but not use it here..
		$turn==1 and ($dx, $dy) = (5-$dy, $dx);
		$turn==2 and ($dx, $dy) = (5-$dx, 5-$dy);
		$turn==3 and ($dx, $dy) = ($dy, 5-$dx);
		my $px = $x + int( $dx * $patch_size*$scale / 5);
		my $py = $y + int( $dy * $patch_size*$scale / 5);
		$pl->addPt($px, $py);
		$DEBUG and print "- ($px, $py) ($dx, $dy, $pt)\n";
	}
	if( $turn && 0 )
	{
		my $pi = 3.141592;
		my ($dx, $dy) = (2, 2);
		my $s = $patch_size * $scale;
		my ($cx, $cy) = ($patch_size*$scale);
		$cx = $x + 0.5*$patch_size*$scale;
		$cy = $y + 0.5*$patch_size*$scale;
		$DEBUG and print " - (cx, cy, $turn) = ($cx, $cy, $turn)\n";
		$pl->rotate($pi/2*$turn, $cx, $cy);
	}
	
	# if stroke color was specified, apply stroke
	# stroke color should be specified if fore color is too close to the
	# back color.
	if( $stroke )
	{
		$image->polyline($pl, $stroke);
		$DEBUG and print "- stroke\n";
	}

	# render rotated patch using fore color (back color if inverted)
	$image->filledPolygon($pl, $fore);
	
	$r;
}

package Image::Identicon;

# -----------------------------------------------------------------------------
# End of Module.
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
__END__

=encoding utf8

=for stopwords
	YAMASHINA
	Hio
	ACKNOWLEDGEMENTS
	AnnoCPAN
	CPAN
	RT
	GPL2
	Identicon

=head1 NAME

Image::Identicon - Generate Identicon image

=head1 SEE ALSO

https://clair.hio.jp/~hio/identicon/

http://www.docuverse.com/blog/donpark/2007/01/18/visual-security-9-block-ip-identification

=head1 LICENSE

GPL2 or free?

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

  use Image::Identicon;
  my $identicon = Image::Identicon->new(salt=>$salt);
  my $image = $identicon->render(); # or pass 32bit integer.
	
	print "Content-Type: image/png\r\n";
	binmode(*STDOUT);
	print $image->{image}->png;

=head1 EXPORT

no functions exported.

=head1 METHODS

=head2 $pkg->new({ salt=>$salt })

Create generator.

=head2 $identicon->render()

Render Image.
Returns hashref.
$result->{image} will be GD::Image instance.

=head2 $identicon->identicon_code()

calculate 32bit Identicon code from IP address.

=head1 AUTHOR

YAMASHINA Hio, C<< <hio at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-image-identicon at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Image-Identicon>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Image::Identicon

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Image-Identicon>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Image-Identicon>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Image-Identicon>

=item * Search CPAN

L<http://search.cpan.org/dist/Image-Identicon>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 YAMASHINA Hio, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation.

=cut
