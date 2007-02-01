#! /usr/bin/perl -w
use strict;
use warnings;
use CGI qw(escapeHTML);
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);

our $TMPL_FILE = 'index.tmpl.html';

__PACKAGE__->do_work(@ARGV);

# -----------------------------------------------------------------------------
# main.
#
sub do_work
{
	our $CGI = CGI->new();
	
	my $addr = $CGI->param('addr') || $CGI->param('ar') || $ENV{REMOTE_ADDR} || '';
	if( $CGI->param('random') )
	{
		$addr = join('.', map{int(rand(256))}1..4);
	}
	
	open(my $fh, '<', $TMPL_FILE) or die "could not open template file [$TMPL_FILE]: $!";
	my $tmpl = join('', <$fh>);
	close ($fh);
	
	if( $addr && !is_valid_address($addr) )
	{
		$tmpl =~ s{<!begin:image>.*<!end:image>\r?\n}{invalid ip address: $addr}sg;
		$addr = escapeHTML($addr);
		$tmpl =~ s{<&ADDR>}{$addr}g;
	}elsif( $addr )
	{
		$tmpl =~ s{<!begin:image>(.*)<!end:image>\n}{$1}sg;
		$tmpl =~ s{<&ADDR>}{$addr}g;
	}else
	{
		$tmpl =~ s{<!begin:image>.*<!end:image>\r?\n}{}sg;
		$tmpl =~ s{<&ADDR>}{}g;
	}
	print "Content-Type: text/html; charset=utf-8\r\n\r\n";
	print $tmpl;
}

sub is_valid_address
{
	my $addr = shift;
	my @ip = $addr =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
	my $packed = pack("C*", @ip);
	join('.', unpack("C*",$packed)) eq $addr;
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
