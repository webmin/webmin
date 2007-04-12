#!/usr/local/bin/perl

require "./fdisk-lib.pl";
&ReadParse();
&can_edit_disk($in{'drive'}) || &error($text{'edit_ecannot'});

if( $in{ 'action' } eq $text{ 'hdparm_apply' } ) 
{
	&ui_print_header(undef,  $text{ 'hdparm_apply' }, "");

	local $command = "hdparm ";
	local $key;
	foreach $key ( 'a', 'd', 'r', 'k', 'u', 'm', 'c', 'A', 'K', 'P', 'X', 'W', 'S' )
	{
		$command .= "-".$key." ".$in{ $key }." " if( $in{ $key } ne "" );
	}
	$command .= $in{ 'drive' }."\n";

	local $out = "<p>". $text{ 'hdparm_performing' }. " : <b>". $command. "</b><i>". &backquote_logged($command). "</i><p>";
	$out =~ s/\n/<br>/g;
	&webmin_log("hdparm", undef, $in{'drive'}, \%in);

	print( $out );
} else {
	&ui_print_header(undef,  $text{'hdparm_speed'}, "");

	local ( $_, $_, $buffered, $buffer_cache ) = split( /\n/, `hdparm -t -T $in{ 'drive' }` );
	( $_, $buffered ) = split( /=/, $buffered );
	( $_, $buffer_cache ) = split( /=/, $buffer_cache );

	print "<p><table border cellpadding=2>\n";
	print "<tr $tb> <td colspan=2>",
	      "<b>$text{'hdparm_speedres'}</b></td> </tr>\n";
	print "<tr $cb> <td><b>$text{'hdparm_buf1'}</b></td> ",
	      "<td>$buffered</td> </tr>\n";
	print "<tr $cb> <td><b>$text{'hdparm_buf2'}</b></td> ",
	      "<td>$buffer_cache</td> </tr>\n";
	print "</table><p>\n";
}

&ui_print_footer( "", $text{ 'index_return' } );

