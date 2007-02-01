#! /usr/bin/perl
## ----------------------------------------------------------------------------
#  identicon.cgi.
# -----------------------------------------------------------------------------
# Mastering programmed by YAMASHINA Hio
#
# Copyright 2007 YAMASHINA Hio
# -----------------------------------------------------------------------------
# $Id$
# -----------------------------------------------------------------------------
use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use lib 'lib';
use Image::Identicon;

our $DEBUG;
BEGIN{ *DEBUG = \$Image::Identicon::DEBUG; };
$DEBUG = 0;

&do_work;

sub do_work
{
	if( $DEBUG )
	{
		print "Content-Type: text/html\r\n\r\n";
		print "<html>\n<head><title>identicon</title>\n</head>\n<body>\n<pre>";
	}
	
	my $CGI = CGI->new();
	my $SALT = "TEST";
	my $identicon = Image::Identicon->new({ salt=>$SALT });
	
	my $code  = $CGI->param('code');
	my $scale = $CGI->param('scale');
	
	$code ||= $identicon->identicon_code($CGI->param('addr') || $CGI->param('ar'));
	$scale =~ /^(\d+)$/ or die "invalid scale: $scale";
	$scale >= 100 and $scale = 100;
	
	my $r = $identicon->render($code, $scale);
	my $image = $r->{image};
	if( !$DEBUG )
	{
		binmode(*STDOUT);
		print "Content-Type: image/png\r\n\r\n";
		print $image->png;
	}else
	{
		print qq{</pre>\n};
		print_as_text($image);
	}
}

sub print_as_text
{
	my $image = shift;
	print qq{<pre style="">};
	my $width  = $image->width;
	my $height = $image->height;
	print "(width, height) = ($width, $height)\n";
	for my $y (0..$image->width-1)
	{
		for my $x (0..$image->height-1)
		{
			my $p = $image->getPixel($x, $y);
			#$p = sprintf('[%3d]', $p);
			print $p==0x00FFFFFF ? '.' : '*';
		}
		print "\n";
	}
	print qq{</pre>\n};
}


