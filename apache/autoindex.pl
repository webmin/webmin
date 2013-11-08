# autoindex.pl
# Directives in both mod_dir.pl and mod_autoindex.pl

@AddIcon_dirs = ("AddIcon", "AddIconByType", "AddIconByEncoding");
@AddIcon_descs = ("$text{'autoindex_fname'}", "$text{'autoindex_mime'}", "$text{'autoindex_enc'}");

sub edit_AddIcon_AddIconByType_AddIconByEncoding
{
local($rv, @all, $i, $j, $icon, $alt, $mode, $file);
$rv = "<table border>\n".
"<tr $tb> <td><b>$text{'autoindex_icon'}</b></td> <td><b>$text{'autoindex_alt'}</b></td>\n".
"<td><b>$text{'autoindex_match'}</b></td> <td><b>$text{'autoindex_fte'}</b></td></tr>\n";
@all = (@{$_[0]}, @{$_[1]}, @{$_[2]});
for($i=0; $i<=@all; $i++) {
	$d = $all[$i];
	if ($d) {
		if ($d->{'value'} =~ /^\((.*),(\S+)\)\s*(.*)$/) {
			$alt = $1; $icon = $2; $file = $3;
			}
		elsif ($d->{'value'} =~ /^(\S+)\s*(.*)$/) {
			$alt = ""; $icon = $1; $file = $2;
			}
		$mode = &indexof($d->{'name'}, @AddIcon_dirs);
		}
	else { $alt = $icon = $file = ""; $mode = 0; }

	$rv .="<tr $cb>\n";
	$rv .="<td><input name=AddIcon_icon_$i size=25 value=\"$icon\"></td>\n";
	$rv .="<td><input name=AddIcon_alt_$i size=10 value=\"$alt\"></td>\n";
	$rv .="<td><select name=AddIcon_mode_$i>\n";
	for($j=0; $j<@AddIcon_descs; $j++) {
		$rv .= sprintf "<option value=$j %s>%s</option>\n",
		        $mode == $j ? "selected" : "", $AddIcon_descs[$j];
		}
	$rv .="</select></td>\n";
	$rv .="<td><input name=AddIcon_file_$i size=20 value=\"$file\"></td>\n";
	$rv .="</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'autoindex_diricon'}", $rv);
}
sub save_AddIcon_AddIconByType_AddIconByEncoding
{
local($i, $icon, $alt, $file, $mode, $aref, @ai, @ait, @aie);
for($i=0; defined($in{"AddIcon_icon_$i"}); $i++) {
	$icon = $in{"AddIcon_icon_$i"}; $alt = $in{"AddIcon_alt_$i"};
	$mode = $in{"AddIcon_mode_$i"}; $file = $in{"AddIcon_file_$i"};
	if ($icon !~ /\S/ && $file !~ /\S/) { next; }
	$icon =~ /^\S+$/ || &error(&text('autoindex_eiconurl', $icon));
	$file =~ /\S/ || &error(&text('autoindex_emiss', $AddIcon_descs[$mode], $icon));
	$aref = $mode==0 ? \@ai : $mode==1 ? \@ait : \@aie;
	if ($alt) { push(@$aref, "($alt,$icon) $file"); }
	else { push(@$aref, "$icon $file"); }
	}
return ( \@ai, \@ait, \@aie );
}

sub edit_DefaultIcon
{
return (1, "$text{'autoindex_deficon'}",
        &opt_input($_[0]->{'value'}, "DefaultIcon", "$text{'autoindex_default'}", 20));
}
sub save_DefaultIcon
{
return &parse_opt("DefaultIcon", '^\S+$', "$text{'autoindex_edeficon'}");
}

@AddAlt_dirs = ("AddAlt", "AddAltByType", "AddAltByEncoding");
@AddAlt_descs = ("Filename", "MIME type", "Encoding");

sub edit_AddAlt_AddAltByType_AddAltByEncoding
{
local($rv, @all, $i, $j, $alt, $mode, $file);
$rv = "<table border>\n".
"<tr $tb> <td><b>$text{'autoindex_alt'}</b></td>\n".
"<td><b>$text{'autoindex_match'}</b></td> <td><b>$text{'autoindex_fte'}</b></td></tr>\n";
@all = (@{$_[0]}, @{$_[1]}, @{$_[2]});
for($i=0; $i<=@all; $i++) {
	$d = $all[$i];
	if ($d->{'value'}) {
		$alt = $d->{'words'}->[0];
		@w = @{$d->{'words'}};
		$file = join(' ', @w[1..$#w]);
		$mode = &indexof($d->{'name'}, @AddAlt_dirs);
		}
	else { $alt = $file = ""; $mode = 0; }

	$rv .="<tr $cb>\n";
	$rv .="<td><input name=AddAlt_alt_$i size=20 value=\"$alt\"></td>\n";
	$rv .="<td><select name=AddAlt_mode_$i>\n";
	for($j=0; $j<@AddAlt_descs; $j++) {
		$rv .= sprintf "<option value=$j %s>%s</option>\n",
		        $mode == $j ? "selected" : "", $AddAlt_descs[$j];
		}
	$rv .="</select></td>\n";
	$rv .="<td><input name=AddAlt_file_$i size=20 value=\"$file\"></td>\n";
	$rv .="</tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'autoindex_diralt'}", $rv);
}
sub save_AddAlt_AddAltByType_AddAltByEncoding
{
local($i, $alt, $file, $mode, $aref, @ai, @ait, @aie);
for($i=0; defined($alt = $in{"AddAlt_alt_$i"}); $i++) {
	$mode = $in{"AddAlt_mode_$i"}; $file = $in{"AddAlt_file_$i"};
	if ($alt !~ /\S/ && $file !~ /\S/) { next; }
	$file =~ /\S/ || &error(&text('autoindex_emissquot', $AddAlt_descs[$mode], $alt));
	$aref = $mode==0 ? \@ai : $mode==1 ? \@ait : \@aie;
	push(@$aref, "\"$alt\" $file");
	}
return ( \@ai, \@ait, \@aie );
}

sub edit_AddDescription
{
local($rv, $i, $desc, $file);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'autoindex_desc'}</b></td> <td><b>$text{'autoindex_fnames'}</b></td> </tr>\n";
for($i=0; $i<=@{$_[0]}; $i++) {
	if ($_[0]->[$i] && $_[0]->[$i]->{'value'} =~ /^"(.*)"\s*(.*)$/)
		{ $desc = $1; $file = $2; }
	else { $desc = $file = ""; }
	$rv .= "<tr $cb> <td><input size=40 name=AddDescription_desc_$i ".
	       "value=\"$desc\"></td>\n";
	$rv .= "<td><input size=20 name=AddDescription_file_$i ".
	       "value=\"$file\"></td> </tr>\n";
	}
$rv .= "</table>\n";
return (2, "$text{'autoindex_dirdesc'}", $rv);
}
sub save_AddDescription
{
local($i, $desc, $file, @rv);
for($i=0; defined($in{"AddDescription_desc_$i"}); $i++) {
	$desc = $in{"AddDescription_desc_$i"};
	$file = $in{"AddDescription_file_$i"};
	if ($desc !~ /\S/ && $file !~ /\S/) { next; }
	$desc =~ /\S/ || &error(&text('autoindex_enodesc', $file));
	$file =~ /\S/ || &error(&text('autoindex_enofile', $desc));
	push(@rv, "\"$desc\" $file");
	}
return ( \@rv );
}

@IndexOptions_v =
	( "FancyIndexing", "ScanHTMLTitles", "IconHeight", "IconWidth",
	  "SuppressColumnSorting", "SuppressDescription",
	  "SuppressHTMLPreamble", "SuppressLastModified", "SuppressSize",
	  "IconsAreLinks", "NameWidth", "DescriptionWidth", "FoldersFirst",
	  "HTMLTable", "IgnoreClient", "SuppressIcon", "SuppressRules",
	  "TrackModified", "VersionSort" );
@IndexOptions_d =
	( $text{'autoindex_fancy'},
	  $text{'autoindex_htmltitle'},
	  $text{'autoindex_iheight'},
	  $text{'autoindex_iwidth'},
	  $text{'autoindex_sort'},
	  $text{'autoindex_fildesc'},
	  $text{'autoindex_htags'},
	  $text{'autoindex_mtime'},
	  $text{'autoindex_size'},
	  $text{'autoindex_iconlink'},
	  $text{'autoindex_fwidth'},
	  $text{'autoindex_dwidth'},
	  $text{'autoindex_dirfirst'},
	  $text{'autoindex_html'},
	  $text{'autoindex_client'},
	  $text{'autoindex_sicon'},
	  $text{'autoindex_srules'},
	  $text{'autoindex_track'},
	  $text{'autoindex_version'} );
@IndexOptions_i = ( 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0 );
@IndexOptions_n = ( 0, 0, 1.3, 1.3,
	            1.3, 0,
		    1.3, 0, 0,
		    1.302, 1.302, 1.310, 1.310,
		    2.023, 2.023, 2.023, 2.023,
		    2.023, 2.0 );

sub edit_IndexOptions_FancyIndexing
{
local($o, %opts, $i, $rv);
$rv = &choice_input($_[0] || $_[1] ? 0 : 1, "IndexOptions_def", 1,
		    "$text{'autoindex_default2'},1", "$text{'autoindex_select'},0");
foreach $o (split(/\s+/, $_[0]->{'value'})) {
	if ($o =~ /^(\S+)=(\S+)$/) { $opts{$1} = $2; }
	else { $opts{$o} = -1; }
	}
if ($_[1]->{'value'} eq "on") { $opts{'FancyIndexing'} = -1; }
$rv .= "<table border><tr><td><table cellpadding=0>\n";
local $sw = 0;
for($i=0; $i<@IndexOptions_v; $i++) {
	$o = $IndexOptions_v[$i];
	next if ($_[2]->{'version'} < $IndexOptions_n[$i]);

	$rv .= "<tr>\n" if (!$sw);
	if ($IndexOptions_i[$i]) { $opts{$o} = -$opts{$o}-1; }
	$rv .= sprintf "<td><input type=checkbox name=Index_$o value=1 %s> %s\n",
	        $opts{$o} ? "checked" : "", $IndexOptions_d[$i];
	if ($o =~ /IconWidth|IconHeight/) {
		$rv .= "&nbsp;";
		$rv .= sprintf 
		        "<input type=radio name=Index_${o}_def value=1 %s> $text{'autoindex_default3'}\n",
		        $opts{$o} < 0 ? "checked" : "";
		$rv .= sprintf
		        "&nbsp;<input type=radio name=Index_${o}_def value=0 %s>\n",
		        $opts{$o} < 0 ? "" : "checked";
		$rv .= sprintf
		        "<input name=Index_${o}_wh size=5 value=\"%s\"> $text{'autoindex_pixels'}\n",
		        $opts{$o} < 0 ? "" : $opts{$o};
		}
	elsif ($o =~ /NameWidth|DescriptionWidth/) {
		$rv .= "&nbsp;";
		$rv .= sprintf
		        "<input name=Index_${o}_w size=5 value=\"%s\"> $text{'autoindex_chars'}\n",
		        $opts{$o} < 0 ? "" : $opts{$o};
		}
	$rv .= "</td>";
	$rv .= "</tr>\n" if ($sw);
	$sw = !$sw;
	}
$rv .= "</table></td></tr></table>\n";
return (2, "$text{'autoindex_diropt'}", $rv);
}
sub save_IndexOptions_FancyIndexing
{
local($i, $o, @rv, %opts);
if ($in{'IndexOptions_def'}) { return ( [ ], [ ] ); }
for($i=0; $i<@IndexOptions_v; $i++) {
	$o = $IndexOptions_v[$i];
	next if ($_[0]->{'version'} < $IndexOptions_n[$i]);

	if ($in{"Index_$o"}) { $opts{$o} = -1; }
	if ($o =~ /IconWidth|IconHeight/ &&
	    $in{"Index_${o}"} && !$in{"Index_${o}_def"}) {
		$in{"Index_${o}_wh"} =~ /^[1-9]\d*$/ ||
			&error(&text('autoindex_eiconsize', $in{"Index_${o}_wh"}));
		$opts{$o} = $in{"Index_${o}_wh"};
		}
	elsif ($o =~ /NameWidth|DescriptionWidth/ && $in{"Index_${o}"}) {
		$in{"Index_${o}_w"} =~ /^[1-9]\d*$/ ||
		    $in{"Index_${o}_w"} eq '*' ||
			&error(&text('autoindex_ewidth', $in{"Index_$(o)_h"}));
		$opts{$o} = $in{"Index_${o}_w"};
		}
	if ($IndexOptions_i[$i]) { $opts{$o} = -$opts{$o}-1; }
	if ($opts{$o} < 0) { push(@rv, "$o"); }
	elsif ($opts{$o} > 0) { push(@rv, "$o=$opts{$o}"); }
	}
return ( [ join(' ', @rv) ], [ ] );
}

sub edit_HeaderName
{
return (1, "$text{'autoindex_dirhead'}",
        &opt_input($_[0]->{'value'}, "HeaderName", "$text{'autoindex_default4'}", 20));
}
sub save_HeaderName
{
return &parse_opt("HeaderName", '^\S+$', "$text{'autoindex_edirhead'}");
}

sub edit_ReadmeName
{
return (1, "$text{'autoindex_dirfoot'}",
        &opt_input($_[0]->{'value'}, "ReadmeName", "$text{'autoindex_default4'}", 20));
}
sub save_ReadmeName
{
return &parse_opt("ReadmeName", '^\S+$', "$text{'autoindex_edirfoot'}");
}

sub edit_IndexIgnore
{
local($rv, $i, @ii);
foreach $i (@{$_[0]}) { push(@ii, split(/\s+/, $i->{'value'})); }
$rv = join("\n", @ii);
return (1, "$text{'autoindex_ignore'}",
        "<textarea name=IndexIgnore rows=5 cols=20>$rv</textarea>");
}
sub save_IndexIgnore
{
local(@rv); @rv = split(/\s+/, $in{'IndexIgnore'});
if (!@rv) { return ( [ ] ); }
else { return ( [ join(' ', @rv) ] ); }
}

1;

