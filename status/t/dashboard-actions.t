#!/usr/bin/perl
# Check the real service CGIs' return URLs without running service commands.
use strict;
use warnings;
use Test::More;
use FindBin;
use Cwd qw(abs_path);

my $root = abs_path("$FindBin::Bin/../..");
require "$root/web-lib-funcs.pl";
our (%in, %access, %text, %gconfig);
%access = ( stop => 1, bootup => 2 );
%gconfig = ( webprefix => '/webmin' );

# Keep the actual request parser and redirect helpers. Stub module loading,
# logging and service operations so these checks cannot affect the host.
{
	no warnings qw(redefine once);
	$INC{'./'.$_.'-lib.pl'} = 1 for qw(fail2ban firewalld nginx init);
	*main::get_miniserv_config = sub { };
	*main::load_theme_library = sub { };
	*main::webmin_log = sub { };
	*main::error = sub { die join('', @_); };
	no strict 'refs';
	foreach my $name (qw(start_fail2ban_server stop_fail2ban_server
		restart_fail2ban_server start_firewalld stop_firewalld
		apply_firewalld start_nginx stop_nginx apply_nginx test_config)) {
		*{"main::$name"} = sub { return undef; };
	}
	*{"main::list_action_names"} = sub { return 'review-service'; };
	*{"main::$_"} = sub { return (1, ''); }
		for qw(start_action stop_action restart_action);
}

# response(cgi, referer, &fields)
# Submit a POST to the actual handler and capture its redirect response.
sub response
{
my ($cgi, $referer, $fields) = @_;
# Build the same body and referrer a browser submits
my $body = join('&', map { urlize($_).'='.urlize($fields->{$_}) }
			sort(keys(%$fields)));
local %ENV = ( %ENV, SCRIPT_NAME => '/'.$cgi, REQUEST_METHOD => 'POST',
	       QUERY_STRING => '', CONTENT_LENGTH => length($body),
	       SERVER_NAME => 'review.invalid', SERVER_PORT => 10000,
	       HTTPS => 'ON', HTTP_REFERER => $referer );
local %in;
open(local *STDIN, '<', \$body) or die $!;
# Capture CGI headers while service operations remain stubbed
my $output = '';
open(my $fh, '>', \$output) or die $!;
my $old = select($fh);
do "$root/$cgi";
my $err = $@;
select($old);
close($fh);
die $err if ($err);
return $output;
}

# Check dashboard and sidebar return pages through each real handler
my @handlers = ( (map { my $mod = $_;
	map { "$mod/$_.cgi" } qw(start stop restart) }
	qw(fail2ban firewalld nginx)), 'init/monitor_action.cgi' );
foreach my $cgi (@handlers) {
	my %fields = ( name => 'review-service', action => 'start' );
	foreach my $page ('/sysinfo.cgi?mod=virtual-server',
			 '/software/?search=php') {
		my $url = 'https://review.invalid:10000/webmin'.$page;
		like(response($cgi, $url, \%fields), qr/Location: \Q$url\E\n/,
		     "$cgi returns to the submitting page with its query");
	}
	# Only Nginx, whose own pages send one, accepts a return URL in the
	# request. The others use the submitting page.
	my $from = 'https://review.invalid:10000/webmin/sysinfo.cgi';
	my $got = response($cgi, $from, { %fields, redir => '/status/' });
	if ($cgi =~ /^nginx\//) {
		my $url = 'https://review.invalid:10000/webmin/status/';
		like($got, qr/Location: \Q$url\E\n/,
		     "$cgi keeps explicit return URLs");
	}
	else {
		like($got, qr/Location: \Q$from\E\n/,
		     "$cgi ignores a return URL in the request");
	}
}

# FirewallD's own forms choose a zone, which takes precedence over the referrer.
foreach my $action (qw(start stop restart)) {
	like(response("firewalld/$action.cgi",
		      'https://review.invalid:10000/webmin/sysinfo.cgi',
		      { zone => 'public' }),
	     qr{Location: https://review\.invalid:10000/webmin/firewalld/index\.cgi\?zone=public\n},
	     "FirewallD $action preserves the submitted zone");
}

# A theme can ask a handler to pass the form's fields on to the return page.
# They start a query on a page that has none, and extend one that exists.
foreach my $case ([ '/acl/', '/acl/?' ],
		  [ '/sysinfo.cgi?mod=status', '/sysinfo.cgi?mod=status&' ]) {
	my ($page, $start) = @$case;
	my $base = 'https://review.invalid:10000/webmin';
	like(response('fail2ban/stop.cgi', $base.$page,
		      { 'pass-query-string' => 1, 'feature' => 'dns' }),
	     qr/Location: \Q$base$start\Efeature=dns\n/,
	     "passed fields are joined correctly to $page");
}

# Passed fields are encoded, so neither a name nor a value can change the
# return address, and the next page reads back what was sent. A plain name
# stays as it is, as themes look for it in the address.
{
	my $base = 'https://review.invalid:10000/webmin';
	my $value = "a&b=c #1+2\r\nX-Test: 1";
	my $name = "odd&name=x\r\nX-Test: 2";
	my $got = response('fail2ban/stop.cgi', $base.'/acl/',
			   { 'pass-query-string' => 1, 'no-cache' => 1,
			     'note' => $value, $name => 'kept' });
	my ($query) = $got =~ /^Location: \Q$base\E\/acl\/\?(\S+)\n\n\z/;
	ok(defined($query),
	   'a passed name or value keeps the redirect on one line');
	like($query, qr/(^|&)no-cache=1(&|$)/,
	     'a plain field name is passed on unchanged');
	# Parse the return address the way the next page does
	local %ENV = ( %ENV, REQUEST_METHOD => 'GET', QUERY_STRING => $query );
	local %in;
	ReadParse();
	is($in{'note'}, $value, 'the next page reads the value that was sent');
	is($in{$name}, 'kept', 'the next page reads the name that was sent');
	is(scalar(keys(%in)), 3, 'no extra field is made from a name or value');
}
done_testing();
