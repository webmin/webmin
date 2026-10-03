#!/usr/local/bin/perl
# Remember a choice made in the menu of the single page layout, such as the
# menu mode, a domain or a managed system, and open a page for it. Also
# sends the menu panel to a page that loads it.
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

# Globals; %theme_menu_pages comes from menu-lib.pl
our %in;
our %text;
our %theme_menu_pages;

# The request only sets a cookie and redirects to a page on this server
our $trust_unknown_referers = 1;

# Load the theme and the functions that build the menu
require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";
ReadParse();
theme_menu_lib() || error(text('left_elib', html_escape($@)));

if ($in{'fragment'}) {
	# The menu panel of a page that runs as a Unix user and loads its menu
	# from here: built for that page's address, module and the page the
	# browser came from, with the choices it shows stored in the cookie
	$ENV{'REQUEST_URI'} = theme_menu_local_url($in{'page'}) ? $in{'page'}
								 : "";
	$ENV{'HTTP_REFERER'} = $in{'ref'};
	$main::gray_theme_menu_module = $in{'module'} =~ /^[\w\-]+$/ ?
						$in{'module'} : "";
	my $html = theme_menu_html({ 'single' => 1, 'fragment' => 1 });
	print "Set-Cookie: ".theme_menu_cookie_string(theme_menu_state())."\n";
	PrintHeader();
	print $html;
	exit;
	}

# Start from the remembered choices
my %state = %{theme_menu_state()};
if ($in{'mode'} =~ /^[\w.\-]+$/) {
	# A new menu mode
	$state{'mode'} = $in{'mode'};
	}

# Look up a domain or system chosen in a menu field the same way the menu
# does, so only one the menu can show is remembered. Build the menus with
# the remembered value for the other one, so choosing a system leaves the
# remembered domain alone, and the other way around.
my %ask = map { $_, $state{$_} } grep { $state{$_} ne '' } ('dom', 'sid');
my %asked;
foreach my $k ('dom', 'dname', 'sid') {
	next if ($in{$k} eq '');
	$ask{$k} = $in{$k};
	$asked{$k eq 'dname' ? 'dom' : $k}++;
	}
if ($in{'dname'} ne '' && $in{'dom'} eq '') {
	# The Virtualmin menu looks up a name only when no domain ID is given
	delete($ask{'dom'});
	}
my %changed;
if (%asked) {
	# Build the menus with the new value, and keep what they show for it
	my @items = list_combined_webmin_menu(theme_settings(), \%ask);
	my $sel = theme_menu_selection(\@items);
	foreach my $k (keys %asked) {
		next if ($sel->{$k} eq '');
		$changed{$k}++ if ($sel->{$k} ne $state{$k});
		$state{$k} = $sel->{$k};
		}
	}

# Work out the page to open next
my $url;
my $field = $in{'field'};
if (theme_menu_local_url($in{'goto'}) && $field =~ /^\w+$/) {
	# The field names a page for its value, such as a domain summary
	my $value = $field =~ /^(dom|sid)$/ && $state{$field} ne '' ?
			$state{$field} : $in{$field};
	$url = $in{'goto'}.urlize($value);
	}
elsif ($changed{'dom'} || $changed{'sid'}) {
	# A page showing the new domain or system
	my $k = $changed{'dom'} ? 'dom' : 'sid';
	$url = $theme_menu_pages{$k}.urlize($state{$k});
	}
elsif (theme_menu_local_url($in{'return'})) {
	# Back to the index of the module the menu was on, or to the system
	# information page
	$url = $in{'return'};
	}
else {
	# The system information page
	$url = "/right.cgi";
	}

# Store the choices and redirect with a path only, so the browser stays on
# the host it used
print "Set-Cookie: ".theme_menu_cookie_string(\%state)."\n";
theme_local_redirect($url);
