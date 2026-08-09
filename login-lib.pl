# login-lib.pl
# Common functions for the built-in login pages.

# get_login_http_warning(&miniserv-config)
# Returns the insecure-login warning HTML, or undef if none is needed
sub get_login_http_warning
{
my ($miniserv) = @_;
return undef if ($ENV{'HTTPS'} eq 'ON' ||
		 (!$miniserv->{'ssl'} && $miniserv->{'no_ssl_warn'}));

my $warning = "&#9888; $text{'login_notsecure'}";
my $description = $text{'login_notsecure_http_desc'};
if ($miniserv->{'ssl'}) {
	$warning = ui_tag('a', $warning,
		{ 'href' => "javascript:void(0);",
		  'class' => 'inherit-color',
		  'onclick' => "window.location.href = ".
		    "window.location.href.replace(/^http:/, 'https:'); return false;",
		});
	$description = $text{'login_notsecure_desc'};
	}
return ui_tag('span', $warning,
	{ class => 'not-secure', title => $description });
}

1;
