#!/usr/local/bin/perl
# edit_hdparm.cgi
# Edit an IDE parameters for some disk

require './fdisk-lib.pl';
&ReadParse();
@dlist = &list_disks_partitions();
$d = $dlist[$in{'disk'}];
&can_edit_disk($d->{'device'}) ||
	&error($text{'edit_ecannot'});

&ui_print_header(undef, $text{'hdparm_title'}, "");
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

print(
"<script type=\"text/javascript\" src=\"range.js\"></script>
<script type=\"text/javascript\" src=\"timer.js\"></script>
<script type=\"text/javascript\" src=\"slider.js\"></script>
<link type=\"text/css\" rel=\"StyleSheet\" href=\"winclassic.css\" />");


print(
"<form action=apply_hdparm.cgi><table border cols=1 width=\"100%\"><input type=hidden name=drive value=", $d -> { 'device' }, ">",
    "<tr ", $tb, ">",
    	"<td><b>", $d->{'desc'}," (",$d->{'device'}.") : ",$text{ 'hdparm_label' }, "</b></td>",
    "</tr><tr ", $cb, "><td>",
	"<table width=\"100%\">",
	    "<tr>",
    		"<td>", &hlink( "<b>". $text{ 'hdparm_conf_X' }. "</b>", 'X' ), &p_select_wdl( "X", $hdparm{ 'X' }, ( "0", $text{ 'hdparm_conf_X_defaut' }, "1", $text{ 'hdparm_conf_X_disable' }, "9", "PIO mode 1", "10", "PIO mode 2", "11", "PIO mode 3", "12", "PIO mode 4", "32", "Multimode DMA 0", "33", "Multimode DMA 1", "34", "Multimode DMA 2", "64", "Ultra DMA 0", "65", "Ultra DMA 1", "66", "Ultra DMA 2" ) ), "</td>",
		"<td>", &l_radio( $text{ 'hdparm_conf_d' }, 'd', @yesno ), "</td>",
	    "</tr><tr>",
		"<td>", &hlink( "<b>". $text{ 'hdparm_conf_a' }. "</b>", "a" ), " ", &p_entry( "a", 2, $hdparm{ 'a' } ), "</td>",
		"<td>", &l_radio( $text{ 'hdparm_conf_A' }, 'A', @yesno ), "</td>",
	    "</tr><tr>",
		"<td>", &l_radio( $text{ 'hdparm_conf_W' }, 'W', @yesno ), "</td>",
		"<td>", &l_radio( $text{ 'hdparm_conf_u' }, 'u', @yesno ), "</td>",
	    "</tr><tr>",
		"<td>", &l_radio( $text{ 'hdparm_conf_k' }, 'k', @yesno ), "</td>",
		"<td>", &l_radio( $text{ 'hdparm_conf_K' }, 'K', @yesno ), "</td>",
	    "</tr><tr>",
		"<td>", &l_radio( $text{ 'hdparm_conf_r' }, 'r', @yesno ), "</td>",
		"<td>", &l_radio( $text{ 'hdparm_conf_P' }, 'P', @yesno ), "</td>",
	    "</tr><tr>",
		"<td>", &hlink( "<b>". $text{ 'hdparm_conf_S' }. "</b>", "S" ), "</td>", "<td>", &p_slider( "S", 0, 251, 0), 
"<script type=\"text/javascript\">

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

</script></td>",
	    "</tr>",
	"</table><table>",
	    "<tr><td>", &l_radio( $text{ 'hdparm_conf_c' }, 'c', ( "0", $text{ 'hdparm_disable' }, "1", $text{ 'hdparm_enable' }, "3", $text{ 'hdparm_enable_special' } ) ), "</td></tr>",
	    "<tr><td>", &l_radio( $text{ 'hdparm_conf_m' }, 'm', ( "0", $text{ 'hdparm_disable' }, "2", "2", "4", "4", "8", "8", "16", "16", "32", "32" ) ), "<td><tr>",
	"</table></td>",
    "</tr>",
"</table><table cols=3 width=\"100%\" nosave>",
    "<tr>",
	"<td align=left><input type=submit name=action value=\"", $text{ 'hdparm_apply' }, "\"></td>",
	"<td align=right><input type=submit name=action value=\"", $text{ 'hdparm_speed' }, "\"></td>",
    "</tr>",
"</table></form>" );

&ui_print_footer( "", $text{ 'index_return' } );

sub l_radio
{
    my ( $label, $flag, @items ) = @_;
    return &hlink( "<b>".$label."</b>", $flag )."</td> <td>".
	   &p_radio( $flag, $hdparm{ $flag }, @items );
}

sub p_radio
{
    my ( $name, $checked, @list ) = @_;
    local $out, $size = @list, $i = 0;

    do
    {
	$out .= " <input type=radio name=".$name." value=".$list[$i];
	$out .= " checked" if( $checked eq $list[$i++] );
	$out .="> ".$list[$i++];
    } while( $i < $size );

    return $out;
}

sub p_slider
{
   my ( $name, $min, $max, $default ) = @_;
   local $out;

   $out .= "<div class=\"slider\" id=\"". $name ."-slider\" tabIndex=\"1\">";
   $out .= "<input class=\"slider-input\" id=\"".$name."-slider-input\"";
   $out .= " name=\"".$name."\"/></div></td><td>";
   $out .= "<input type=text name=\"".$name."-text\" id=\"".$name."-text-id\" readonly value=\"This field is not used\" >";

   return $out;
}

sub p_entry
{
    my ( $name, $size, $value ) = @_;

    $size ? return "</td> <td><input name=\"". $name. "\" id=\"". $name. "-id\" size=". $size." value=\"". $value."\">" : return "</td> <td><input name=\"". $name. "\" id=\"". $name. "-id\" value=\"". $value."\">";
}

sub p_select_wdl
{
    my ( $name, $selected, @list ) = @_;
    local $size = @list, $i = 0, $out = "</td> <td><select name=".$name.">";
    do
    {
	$out .= "<option name=".$name." value=".$list[$i];
	$out .= " selected" if( $selected eq $list[$i++] );
	$out .= ">".$list[$i++];
    } while( $i < $size );
    $out .= "</select>";

    return $out;
}
