#!/usr/local/bin/perl
# edit_smem.cgi
# A form for editing simple memory and disk usage options

require './squid-lib.pl';
$access{'musage'} || &error($text{'emem_ecannot'});
&ui_print_header(undef, $text{'emem_dheader'}, "", "", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_smem.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'emem_maduo'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
if ($squid_version < 2) {
	print &opt_input($text{'emem_mul'}, "cache_mem", $conf,
			 $text{'default'}, 6, $text{'emem_mb'});
	print &opt_input($text{'emem_dul'}, "cache_swap",
			 $conf, $text{'default'}, 6, $text{'emem_mb'});
	}
else {
	print &opt_bytes_input($text{'emem_mul'}, "cache_mem", $conf,
			       $text{'default'}, 6);
	print &opt_input($text{'emem_fcs'}, "fqdncache_size", $conf,
			 $text{'default'}, 8);
	}
print "</tr>\n";

print "<tr>\n";
if ($squid_version < 2) {
	print &opt_input($text{'emem_mcos'}, "maximum_object_size",
			 $conf, $text{'default'}, 8, $text{'emem_kb'});
	}
else {
	print &opt_bytes_input($text{'emem_mcos'},
			       "maximum_object_size", $conf, $text{'default'}, 6);
	}
print &opt_input($text{'emem_iacs'}, "ipcache_size", $conf,
		 $text{'default'}, 6, $text{'emem_e'});
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr>\n";
@dirs = &find_config("cache_dir", $conf);
print "<td valign=top><b>$text{'ec_cdirs'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=cache_dir_def value=1 %s>$text{'ec_default'}\n",
	@dirs ? "" : "checked";
printf "<input type=radio name=cache_dir_def value=0 %s>$text{'ec_listed'}<br>\n",
	@dirs ? "checked" : "";
print "<table border>\n";
if ($squid_version >= 2) {
	print "<tr $tb> <td><b>$text{'ec_directory'}</b></td>\n";
	if ($squid_version >= 2.3) {
		print "<td><b>$text{'ec_type'}</b></td>\n";
		}
	print "<td><b>$text{'ec_size'}</b></td>\n";
	print "<td><b>$text{'ec_1dirs'}</b></td>\n";
	print "<td><b>$text{'ec_2dirs'}</b></td>\n";
	if ($squid_version >= 2.4) {
		print "<td><b>$text{'ec_opts'}</b></td>\n";
		}
	print "</tr>\n";
	}
for($i=0; $i<=@dirs; $i++) {
	@dv = $i<@dirs ? @{$dirs[$i]->{'values'}} : ();
	print "<tr $cb>\n";
	if ($squid_version >= 2.4) {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[1]\"></td>\n";
		print "<td><select name=cache_type_$i>\n";
		printf "<option value=ufs %s>$text{'ec_u'}</option>\n",
			$dv[0] eq 'ufs' ? 'selected' : '';
		printf "<option value=diskd %s>$text{'ec_diskd'}</option>\n",
			$dv[0] eq 'diskd' ? 'selected' : '';
		printf "<option value=aufs %s>$text{'ec_ua'}</option>\n",
			$dv[0] eq 'aufs' ? 'selected' : '';
		print "</select></td>\n";
		print "<td><input name=cache_size_$i size=8 ",
		      "value=\"$dv[2]\"></td>\n";
		print "<td><input name=cache_lv1_$i size=8 ",
		      "value=\"$dv[3]\"></td>\n";
		print "<td><input name=cache_lv2_$i size=8 ",
		      "value=\"$dv[4]\"></td>\n";
		print "<td><input name=cache_opts_$i size=10 ",
		      "value=\"",join(" ",@dv[5..$#dv]),"\"></td>\n";
		}
	elsif ($squid_version >= 2.3) {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[1]\"></td>\n";
		print "<td><select name=cache_type_$i>\n";
		printf "<option value=ufs %s>$text{'ec_u'}</option>\n",
			$dv[0] eq 'ufs' ? 'selected' : '';
		printf "<option value=asyncufs %s>$text{'ec_ua'}</option>\n",
			$dv[0] eq 'asyncufs' ? 'selected' : '';
		print "</select></td>\n";
		print "<td><input name=cache_size_$i size=8 ",
		      "value=\"$dv[2]\"></td>\n";
		print "<td><input name=cache_lv1_$i size=8 ",
		      "value=\"$dv[3]\"></td>\n";
		print "<td><input name=cache_lv2_$i size=8 ",
		      "value=\"$dv[4]\"></td>\n";
		}
	elsif ($squid_version >= 2) {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[0]\"></td>\n";
		print "<td><input name=cache_size_$i size=8 ",
		      "value=\"$dv[1]\"></td>\n";
		print "<td><input name=cache_lv1_$i size=8 ",
		      "value=\"$dv[2]\"></td>\n";
		print "<td><input name=cache_lv2_$i size=8 ",
		      "value=\"$dv[3]\"></td>\n";
		}
	else {
		print "<td><input name=cache_dir_$i size=30 ",
		      "value=\"$dv[0]\"></td>\n";
		}
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &opt_input($text{'ec_1dirs1'}, "swap_level1_dirs", $conf,
			 $text{'ec_default'}, 6);
	print &opt_input($text{'ec_2dirs2'}, "swap_level2_dirs", $conf,
			 $text{'ec_default'}, 6);
	print "</tr>\n";
	}

print "<tr>\n";
if ($squid_version < 2) {
	print &opt_input($text{'ec_aos'}, "store_avg_object_size", $conf,
			 $text{'ec_default'}, 6, $text{'ec_kb'});
	}
else {
	print &opt_bytes_input($text{'ec_aos'}, "store_avg_object_size",
			       $conf, $text{'ec_default'}, 6);
	}
print &opt_input($text{'ec_opb'}, "store_objects_per_bucket", $conf,
		 $text{'ec_default'}, 6);
print "</tr>\n";



print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'></form>\n";

&ui_print_footer("", $text{'emem_return'});

