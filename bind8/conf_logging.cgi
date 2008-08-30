#!/usr/local/bin/perl
# conf_logging.cgi
# Display global logging options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'logging_ecannot'});
&ui_print_header(undef, $text{'logging_title'}, "");
&ReadParse();
$conf = &get_config();
$logging = &find("logging", $conf);
$mems = $logging ? $logging->{'members'} : [ ];

# Start of tabs for channels and categories
@tabs = ( [ "chans", $text{'logging_chans'}, "conf_logging.cgi?mode=chans" ],
	  [ "cats", $text{'logging_cats'}, "conf_logging.cgi?mode=cats" ] );
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "chans", 1);

print &ui_tabs_start_tab("mode", "chans");
print $text{'logging_chansdesc'},"<p>\n";

# Add default channels to table
@table = ( );
@defchans = ( { 'name' => 'default_syslog',
		'syslog' => 'daemon',
		'severity' => 'info' },
	      { 'name' => 'default_debug',
		'file' => 'named.run',
		'severity' => 'dynamic' },
	      { 'name' => 'default_stderr',
		'fd' => 'stderr',
		'severity' => 'info' },
	      { 'name' => 'null',
		'null' => 1 } );
foreach $c (@defchans) {
	push(@table, [
		$c->{'name'},
		$c->{'syslog'} ? $c->{'syslog'} :
		$c->{'file'} ? $text{'logging_file'}.
			       " <tt>".$c->{'file'}."</tt>" :
		$c->{'fd'} ? $text{'logging_fd'}." <tt>".$c->{'fd'}."</tt>" :
			     $text{'logging_null'},
		$c->{'severity'} || "<i>$text{'logging_any'}</i>",
		]);
	}

# Add user-defined channels
# XXX
@chans = &find("channel", $mems);
@channames = ( (map { $_->{'value'} } @chans) ,
	       'default_syslog', 'default_debug', 'default_stderr', 'null' );
push(@chans, { }) if ($in{'add'});
for($i=0; $i<@chans; $i++) {
	$cmems = $chans[$i]->{'members'};
	$file = &find("file", $cmems);
	$filestr = $file ? join(" ", @{$file->{'values'}}) : "";
	$syslog = &find_value("syslog", $cmems);
	$null = &find("null", $cmems);

	print "<br>\n" if ($i);
	print "<table width=100% border><tr><td><table width=100%>\n";
	print "<tr> <td><b>$text{'logging_cname'}</b></td>\n";
	printf "<td colspan=3><input name=cname_$i value='%s'></td> </tr>\n",
		$chans[$i]->{'value'};

	print "<tr> <td valign=top><b>$text{'logging_to'}</b></td>\n";
	print "<td colspan=3>\n";
	printf "<input type=radio name=to_$i value=0 %s> %s\n",
		$file ? "checked" : "", $text{'logging_file'};
	printf "<input name=file_$i size=40 value='%s'> %s<br>\n",
		$file->{'value'}, &file_chooser_button("file_$i");

	print "&nbsp;&nbsp;&nbsp;&nbsp;<b>$text{'logging_versions'}</b>\n";
	printf "<input type=radio name=vmode_$i value=0 %s> %s\n",
		$filestr =~ /\sversions\s/i ? "" : "checked",
		$text{'logging_ver1'};
	printf "<input type=radio name=vmode_$i value=1 %s> %s\n",
		$filestr =~ /\sversions\s+unlimited/i ? "checked" : "",
		$text{'logging_ver2'};
	printf "<input type=radio name=vmode_$i value=2 %s>\n",
		$filestr =~ /\sversions\s+(\d+)/i ? "checked" : "";
	printf "<input name=ver_$i size=5 value='%s'><br>\n",
		$filestr =~ /\sversions\s+(\d+)/i ? $1 : "";

	$size = $filestr =~ /\ssize\s+(\S+)/ ? $1 : '';
	$size = undef if ($size eq 'unlimited');
	print "&nbsp;&nbsp;&nbsp;&nbsp;<b>$text{'logging_size'}</b>\n";
	printf "<input type=radio name=smode_$i value=0 %s> %s\n",
		$size ? "" : "checked", $text{'logging_sz1'};
	printf "<input type=radio name=smode_$i value=1 %s>\n",
		$size ? "checked" : "";
	printf "<input name=size_$i size=5 value='%s'><br>\n", $size;

	printf "<input type=radio name=to_$i value=1 %s> %s\n",
		$syslog ? "checked" : "", $text{'logging_syslog'};
	print "<select name=syslog_$i>\n";
	print "<option selected>\n" if (!$syslog);
	foreach $s (@syslog_levels) {
		printf "<option %s>%s\n",
			$syslog eq $s ? "selected" : "", $s;
		}
	print "</select>&nbsp;&nbsp;\n";

	printf "<input type=radio name=to_$i value=2 %s> %s</td> </tr>\n",
		$null ? "checked" : "", $text{'logging_null'};

	$sev = &find("severity", $cmems);
	print "<tr> <td><b>$text{'logging_sev'}</b></td>\n";
	print "<td colspan=3><select name=sev_$i>\n";
	printf "<option %s>\n", $sev ? "" : "selected";
	foreach $s (@severities) {
		printf "<option value=%s %s>%s\n",
			$s, $sev->{'value'} eq $s ? "selected" : "",
			$s eq 'debug' ? $text{'logging_debug'} :
			$s eq 'dynamic' ? $text{'logging_dyn'} : $s;
		}
	print "</select>\n";
	printf "<input name=debug_$i size=5 value='%s'></td> </tr>\n",
		$sev->{'value'} eq 'debug' ? $sev->{'values'}->[1] : "";

	print "<tr> <td><b>$text{'logging_pcat'}</b></td> <td>\n";
	&yes_no_default("print-category-$i",
			&find_value("print-category", $cmems));
	print "</td> <td><b>$text{'logging_psev'}</b></td> <td>\n";
	&yes_no_default("print-severity-$i",
			&find_value("print-severity", $cmems));
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'logging_ptime'}</b></td> <td>\n";
	&yes_no_default("print-time-$i",
			&find_value("print-time", $cmems));
	print "</td> </tr>\n";

	print "</table></td></tr></table>\n";
	}
print "<a href='conf_logging.cgi?add=1'>$text{'logging_add'}</a>\n";
print "</td> </tr>\n";

# Output the channels table
print &ui_form_columns_table(
        "save_logging.cgi",
        [ [ undef, $text{'save'} ] ],
        0,
        undef,
        [ [ 'mode', 'chans' ] ],
	[ $text{'logging_cname'}, $text{'logging_to'}, $text{'logging_sev'} ],
	100,
	\@table,
	undef,
	1);

print &ui_tabs_end_tab("mode", "chans");

# Start of categories tab
print &ui_tabs_start_tab("mode", "cats");
print $text{'logging_catsdesc'},"<p>\n";

# Build table of categories
@table = ( );
@cats = ( &find("category", $mems), { } );
for($i=0; $i<@cats; $i++) {
	my %cchan;
	foreach $c (@{$cats[$i]->{'members'}}) {
		$cchan{$c->{'name'}}++;
		}
	push(@table, [
		&ui_select("cat_$i", $cats[$i]->{'value'},
			   [ [ "", "&nbsp;" ], @cat_list ],
			   1, 0, $cats[$i]->{'value'} ? 1 : 0),
		join(" ", map { &ui_checkbox("cchan_$i", $_, $_, $cchan{$_}) }
			      @channames)
		]);
	}

# Show the table
print &ui_form_columns_table(
	"save_logging.cgi",
	[ [ undef, $text{'save'} ] ],
	0,
	undef,
	[ [ 'mode', 'cats' ] ],
	[ $text{'logging_cat'}, $text{'logging_cchans'} ],
	100,
	\@table,
	undef,
	1);

print &ui_tabs_end_tab("mode", "cats");
print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

# yes_no_default(name, value)
sub yes_no_default
{
printf "<input type=radio name=$_[0] value=yes %s> $text{'yes'}\n",
	lc($_[1]) eq 'yes' ? 'checked' : '';
printf "<input type=radio name=$_[0] value=no %s> $text{'no'}\n",
	lc($_[1]) eq 'no' ? 'checked' : '';
printf "<input type=radio name=$_[0] value='' %s> $text{'default'}\n",
	!$_[1] ? 'checked' : '';
}

