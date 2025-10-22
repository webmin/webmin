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
		$command .= "-".$key." ".quotemeta($in{$key})." " if ($in{$key} ne "");
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

	print &ui_table_start($text{'hdparm_speedres'}, undef, 2,[ "width=30%" ]);
	print &ui_table_row($text{'hdparm_buf1'}, $buffered);
	print &ui_table_row($text{'hdparm_buf2'}, $buffer_cache);
	print &ui_table_end();
}

&ui_print_footer( "", $text{ 'index_return' } );

