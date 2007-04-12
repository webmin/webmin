# mod_mime.pl
# Defines MIME module directives

sub mod_mime_directives
{
local $rv;
$rv = [ [ 'AddType', 1, 6, 'virtual directory htaccess', undef, 10 ],
	[ 'AddHandler', 1, 6, 'virtual directory htaccess', undef, 6 ],
	[ 'AddOutputFilter', 1, 18, 'virtual directory htaccess', 2.0 ],
	[ 'AddInputFilter', 1, 18, 'virtual directory htaccess', 2.0 ],
	[ 'DefaultLanguage', 0, 19, 'virtual directory htaccess', 1.304 ],
	[ 'RemoveHandler', 1, 6, 'directory htaccess', 1.304, 5 ],
	[ 'RemoveType', 1, 6, 'directory htaccess', 1.313, 5 ],
	[ 'RemoveEncoding', 1, 6, 'directory htaccess', 1.313, 5 ],
	[ 'AddLanguage', 1, 19, 'virtual directory htaccess', undef, 4 ],
	[ 'AddEncoding', 1, 6, 'virtual directory htaccess', undef, 8 ],
	[ 'AddCharset', 1, 19, 'virtual directory htaccess', 1.310, 2 ],
	[ 'ForceType', 0, 6, 'directory htaccess', -2.0 ],
	[ 'SetHandler', 0, 6, 'directory htaccess' ],
	[ 'TypesConfig', 0, 6, 'global' ] ];
return &make_directives($rv, $_[0], "mod_mime");
}

# extmap_input(directive, title, size, desc, list)
sub extmap_input
{
local($rv, $i, $type, $exts);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$_[1]</b></td> <td><b>$text{'mod_mime_ext'}</b></td>\n".
      "<td><b>$_[1]</b></td> <td><b>$text{'mod_mime_ext'}</b></td> </tr>\n";
$len = int(@{$_[4]}/2)*2 + 2;
for($i=0; $i<$len; $i++) {
	if ($i%2 == 0) { $rv .= "<tr $cb>\n"; }
	if ($_[4]->[$i]) {
		$_[4]->[$i]->{'value'} =~ /^(\S+)\s*(.*)$/;
		$type = $1; $exts = $2;
		}
	else { $type = $exts = ""; }
	$rv .= "<td>";
	if ($_[2] eq "h") { $rv .= &handler_input($type, "$_[0]_type_$i"); }
	else { $rv .= "<input name=$_[0]_type_$i size=$_[2] value=$type>"; }
	$rv .= "</td>\n";
	$rv .= "<td><input name=$_[0]_exts_$i size=10 value=\"$exts\"></td>\n";
	if ($i%2 == 1) { $rv .= "</tr>\n"; }
	}
$rv .= "</table>\n";
return (2, $_[3], $rv);
}

# parse_extmap(directive, regexp, desc)
sub parse_extmap
{
local($i, $type, $exts, @rv, $re); $re = $_[1];
for($i=0; defined($in{"$_[0]_type_$i"}); $i++) {
	$type = $in{"$_[0]_type_$i"}; $exts = $in{"$_[0]_exts_$i"};
	if ($type !~ /\S/ && $exts !~ /\S/) { next; }
	if ($type !~ /$re/) { &error(&text('mod_mime_einvalid', $type, $_[2])); }
	if ($exts !~ /\S/) { &error(&text('mod_mime_eext', $_[2], $type)); }
	push(@rv, "$type $exts");
	}
return ( \@rv );
}

sub edit_AddType
{
&extmap_input("AddType", $text{'mod_mime_type'}, 20, $text{'mod_mime_xtype'}, $_[0]);
}
sub save_AddType
{
return &parse_extmap("AddType", '^(\S+)\/(\S+)$',
		     $text{'mod_mime_mtype'});
}

sub edit_AddHandler
{
&extmap_input("AddHandler", $text{'mod_mime_handler'}, "h", $text{'mod_mime_chandl'}, $_[0]);
}
sub save_AddHandler
{
return &parse_extmap("AddHandler");
}

sub edit_AddEncoding
{
&extmap_input("AddEncoding", $text{'mod_mime_cenc'}, 20, $text{'mod_mime_cencs'}, $_[0]);
}
sub save_AddEncoding
{
return &parse_extmap("AddEncoding", '^(\S+)$',
		     $text{'mod_mime_cenc'});
}

sub edit_AddLanguage
{
&extmap_input("AddLanguage", $text{'mod_mime_lang'}, 5, $text{'mod_mime_clangs'}, $_[0]);
}
sub save_AddLanguage
{
return &parse_extmap("AddLanguage", '^\S+$', $text{'mod_mime_clang'});
}

sub edit_ForceType
{
return (1, $text{'mod_mime_defmime'},
	&opt_input($_[0]->{'value'}, "ForceType", $text{'mod_mime_real'}, 15));
}
sub save_ForceType
{
return &parse_opt("ForceType", '^\S+\/\S+$', $text{'mod_mime_etype'});
}

sub edit_SetHandler
{
return (1, $text{'mod_mime_pass'},
	&handler_input($_[0]->{'value'}, "SetHandler"));
}
sub save_SetHandler
{
return &parse_handler("SetHandler");
}

sub edit_TypesConfig
{
return (2,
	$text{'mod_mime_file'},
	&opt_input($_[0]->{'value'}, "TypesConfig", $text{'mod_mime_default'}, 40).
	&file_chooser_button("TypesConfig", 0));
}
sub save_TypesConfig
{
return &parse_opt("TypesConfig");
}

sub edit_RemoveHandler
{
local @list;
foreach $v (@{$_[0]}) {
	push(@list, @{$v->{'words'}});
	}
return (2, "$text{'mod_mime_ignhand'}",
	&opt_input(@list ? join(" ", @list) : undef,
		   "RemoveHandler", "$text{'mod_mime_none'}", 40));
}
sub save_RemoveHandler
{
return &parse_opt("RemoveHandler");
}

sub edit_RemoveType
{
local @list;
foreach $v (@{$_[0]}) {
	push(@list, @{$v->{'words'}});
	}
return (2, "$text{'mod_mime_igntype'}",
	&opt_input(@list ? join(" ", @list) : undef,
		   "RemoveType", "$text{'mod_mime_none'}", 40));
}
sub save_RemoveType
{
return &parse_opt("RemoveType");
}

sub edit_RemoveEncoding
{
local @list;
foreach $v (@{$_[0]}) {
	push(@list, @{$v->{'words'}});
	}
return (2, "$text{'mod_mime_ignenc'}",
	&opt_input(@list ? join(" ", @list) : undef,
		   "RemoveEncoding", "$text{'mod_mime_none'}", 40));
}
sub save_RemoveEncoding
{
return &parse_opt("RemoveEncoding");
}

sub edit_AddCharset
{
&extmap_input("AddCharset", "$text{'mod_mime_chars'}", 12, "$text{'mod_mime_xchars'}", $_[0]);
}
sub save_AddCharset
{
return &parse_extmap("AddCharset");
}

sub edit_DefaultLanguage
{
return (1, $text{'mod_mime_deflang'},
	&opt_input($_[0]->{'value'}, "DefaultLanguage", $text{'mod_mime_none'},
		   10));
}
sub save_DefaultLanguage
{
return &parse_opt("DefaultLanguage", '\S', $text{'mod_mime_edeflang'});
}

sub edit_AddOutputFilter
{
return (2, $text{'mod_mime_outfilter'},
	&filtmap_input("AddOutputFilter", $_[0]));
}
sub save_AddOutputFilter
{
return &parse_filtmap("AddOutputFilter");
}

sub edit_AddInputFilter
{
return (2, $text{'mod_mime_infilter'},
	&filtmap_input("AddInputFilter", $_[0]));
}
sub save_AddInputFilter
{
return &parse_filtmap("AddInputFilter");
}

# filtmap_input(name, &values)
sub filtmap_input
{
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'mod_mime_filters'}</b></td>\n".
	    "<td><b>$text{'mod_mime_ext'}</b></td> </tr>\n";
local ($d, $i = 0);
foreach $d (@{$_[1]}, { }) {
	local @w = @{$d->{'words'}};
	local @v = split(/;/, shift(@w));
	$rv .= "<tr $cb>\n";
	$rv .= "<td>".&filters_input(\@v, $_[0]."_f_$i")."</td>\n";
	$rv .= "<td><input name=$_[0]_e_$i size=30 value='".
		join(" ", @w)."'></td>\n";
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
return $rv;
}
# parse_filtmap(name)
sub parse_filtmap
{
local ($i, @rv);
for($i=0; defined($in{"$_[0]_e_$i"}); $i++) {
	local @f = split(/\0/, $in{"$_[0]_f_$i"});
	next if (!@f);
	local $exts = $in{"$_[0]_e_$i"};
	$exts || &error(&text('mod_mime_efext', join(" ", @f)));
	push(@rv, join(";", @f)." ".$exts);
	}
return ( \@rv );
}

1;

