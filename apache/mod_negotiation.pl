# mod_negotiation.pl
# Defines editors content negotiation directives

sub mod_negotiation_directives
{
$rv = [ [ 'CacheNegotiatedDocs', 0, 6, 'global' ],
        [ 'LanguagePriority', 0, 19, 'virtual directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_negotiation");
}

sub mod_negotiation_handlers
{
return ("type-map");
}

sub edit_CacheNegotiatedDocs
{
if ($_[1]->{'version'} < 2.0) {
	local $v = $_[0] ? "1" : "0";
	return (1, $text{'mod_negotiation_cache'},
		&choice_input($v, "CacheNegotiatedDocs", "0",
		"$text{'yes'},1", "$text{'no'},0"));
	}
else {
	return (1, $text{'mod_negotiation_cache'},
		&choice_input($_[0]->{'value'}, "CacheNegotiatedDocs", "off",
			      "$text{'yes'},on", "$text{'no'},off"));
	}
}
sub save_CacheNegotiatedDocs
{
if ($_[0]->{'version'} < 2.0) {
	return $in{'CacheNegotiatedDocs'} ? ( [ "" ] ) : ( [ ] );
	}
else {
	return &parse_choice("CacheNegotiatedDocs", "off");
	}
}

sub edit_LanguagePriority
{
return (2, "$text{'mod_negotiation_pri'}",
        &opt_input($_[0]->{'value'}, "LanguagePriority", "$text{'mod_negotiation_def'}", 40));
}
sub save_LanguagePriority
{
local $rv = &parse_opt("LanguagePriority", '\S', $text{'mod_negotiation_epri'});
if ($rv && @$rv) {
	$rv->[0] =~ s/^"(.*)"/$1/g;
	}
return $rv;
}

1;

