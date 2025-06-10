#!/usr/local/bin/perl
# edit_hdparm.cgi
# Edit an IDE parameters for some disk

require './fdisk-lib.pl';
&ReadParse();
@dlist = &list_disks_partitions();
$d = $dlist[$in{'disk'}];
&can_edit_disk($d->{'device'}) ||
	&error($text{'edit_ecannot'});

&ui_print_header($d->{'desc'}, $text{'hdparm_title'}, "");
if ( ! &has_command( "hdparm" ) ) {
	print "<p>$text{ 'edit_ehdparm' }<p>\n";
	&ui_print_footer( "", $text{ 'index_return' } );
	exit;
	}

%hdparm = ( 'A', "1", 'K', "0", 'P', "0", 'X', "0", 'W', "0", 'S', "0" );
@yesno = ( "1", $text{ 'hdparm_on' }, "0", $text{ 'hdparm_off' } );

foreach $argument ( 'a', 'd', 'r', 'k', 'u', 'm', 'c' )
{
    $out = `hdparm -$argument $d->{'device'}`;
    if ($out =~ /\s+=\s+(\S+)/) {
	$hdparm{ $argument } = $1;
	}
    #( $_, $line ) = split( /=/, `hdparm -$argument $d->{'device'}` );
    #$line =~ s/ {1,}//;
    #( $hdparm{ $argument } ) = split( / /, $line );
}

# Javascript for slider
print(
"<script type=\"text/javascript\" src=\"range.js\"></script>
<script type=\"text/javascript\" src=\"timer.js\"></script>
<script type=\"text/javascript\" src=\"slider.js\"></script>
<link type=\"text/css\" rel=\"StyleSheet\" href=\"winclassic.css\" />");

# Form header
print &ui_form_start("apply_hdparm.cgi");
print &ui_hidden("drive", $d->{'device'});
print &ui_table_start($text{'hdparm_label'}, "width=100%", 4);

# Transfer mode
print &ui_table_row(&hlink($text{'hdparm_conf_X'}, 'X'),
	&ui_select("X", $hdparm{'X'},
		[ [ "0", $text{ 'hdparm_conf_X_defaut' } ], [ "1", $text{ 'hdparm_conf_X_disable' } ], [ "9", "PIO mode 1", ], [ "10", "PIO mode 2" ], [ "11", "PIO mode 3" ], [ "12", "PIO mode 4" ], [ "32", "Multimode DMA 0" ], [ "33", "Multimode DMA 1" ], [ "34", "Multimode DMA 2" ], [ "64", "Ultra DMA 0" ], [ "65", "Ultra DMA 1" ], [ "66", "Ultra DMA 2" ] ], 1, 0, 1));

# Sector count
print &ui_table_row(&hlink($text{'hdparm_conf_a'}, 'sector_count'),
	&ui_textbox("a", $hdparm{'a'}, 2));

# Other yes/no options
foreach $o ('d', 'A', 'W', 'u', 'k', 'K', 'r', 'P') {
	if ($o eq 'k') {
		print &ui_table_row(&hlink($text{'hdparm_conf_'.$o}, 'keep_settings'),
			&ui_yesno_radio($o, $hdparm{$o}));
		}
	else {
		print &ui_table_row(&hlink($text{'hdparm_conf_'.$o}, $o),
			&ui_yesno_radio($o, $hdparm{$o}));
		}
	}

# Standby timeout (slider)
print &ui_table_row(&hlink($text{'hdparm_conf_S'}, 'S'),
	&p_slider( "S", 0, 251, 0), 3);

# 32-bit I/O support
print &ui_table_row(&hlink($text{'hdparm_conf_c'}, 'c'),
	&ui_radio('c', $hdparm{'c'},
		  [ [ 0, $text{'hdparm_disable'} ],
		    [ 1, $text{'hdparm_enable'} ],
		    [ 3, $text{'hdparm_enable_special'} ] ]), 3);

# Sector count for multiple sector I/O
print &ui_table_row(&hlink($text{'hdparm_conf_m'}, 'm'),
	&ui_radio('m', $hdparm{'m'},
		  [ [ 0, $text{'hdparm_disable'} ],
		    [ 2 ], [ 4 ], [ 8 ], [ 16 ], [ 32 ] ]), 3);

print &ui_table_end();
print &ui_form_end([ [ 'action', $text{'hdparm_apply'} ],
		     [ 'action', $text{'hdparm_speed'} ] ]);

&ui_print_footer( "", $text{ 'index_return' } );

# Javascript for slider
print "<script type=\"text/javascript\">

var sliderEl = document.getElementById ?
                  document.getElementById(\"S-slider\") : null;
var inputEl = document.forms[0][\"S\"];

var s = new Slider(sliderEl, inputEl);

function format_time(t_sec) {
	
	if ( t_sec >= 3600 ) {
		var t_hour = (t_sec - (t_sec % 3600))/3600;
		return t_hour + \" hours \" + format_time(t_sec % 3600);
	} else if ( t_sec >= 60 ){
		var t_min = (t_sec - (t_sec % 60))/60;
		return t_min + \" minutes \" + format_time(t_sec % 60);;
	} else if ( t_sec > 0 ){
		return t_sec + \" seconds \";
	} else {
		return \" \";
	}
};

s.onchange = function () {
	var flag = s.getValue();
	var t_sec = 0;
	if (flag < 241) {
		t_sec = flag * 5;
	} else {
		t_sec = (flag -240) * 30 * 60;
	}

	if (t_sec == 0) {
		document.getElementById(\"S-text-id\").value = \"always on\";
	} else {
		document.getElementById(\"S-text-id\").value = format_time(t_sec);
	}
};

s.setValue(0);
s.setMinimum(0);
s.setMaximum(251);

</script>";

# Returns a slider
sub p_slider
{
   my ( $name, $min, $max, $default ) = @_;
   local $out;

   $out .= "<div class=\"slider\" id=\"". $name ."-slider\" tabIndex=\"1\">";
   $out .= "<input class=\"slider-input\" id=\"".$name."-slider-input\"";
   $out .= " name=\"".$name."\"/></div>";
   $out .= "<input type=text name=\"".$name."-text\" id=\"".$name."-text-id\" readonly value=\"This field is not used\" >";

   return $out;
}


