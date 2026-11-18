#!/usr/bin/perl
# Check that dhcpd.conf values cannot break out of their directive, that
# comments survive a re-save, and that lease strings are tokenized like dhcpd.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";

# Compile the real parser and writer into their own package, without module
# initialization.
open(my $fh, '<', "$root/dhcpd/dhcpd-lib.pl") or die $!;
my $code = do { local $/; <$fh> };
close($fh);
foreach my $sub ('tokenize_file', 'parse_struct', 'directive_lines',
		 'directive_value_safe') {
	$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval "package dh; no strict; no warnings; $1";
	die $@ if $@;
	}
*dh::read_file_lines = \&main::read_file_lines;
*dh::html_escape = \&main::html_escape;
*dh::error = sub { die join(' ', @_)."\n" };
*dh::text = sub {
	my ($key, @args) = @_;
	my $msg = $dh::text{$key};
	$msg =~ s/\$(\d+)/$args[$1-1]/g;
	return $msg;
	};
open(my $lang, '<', "$root/dhcpd/lang/en") or die $!;
while (<$lang>) {
	$dh::text{$1} = $2 if /^(\S+)=(.*)$/;
	}
close($lang);

my $tmp = tempdir('dhcpd-quoting.XXXXXX', DIR => '/tmp', CLEANUP => 1);

# parse_file(file)
# Returns the top-level directives parsed from a file.
sub parse_file
{
my ($file) = @_;
my @tok;
dh::tokenize_file($file, \@tok);
my ($i, $j, @rv) = (0, 0);
while ($i < @tok) {
	my $str = dh::parse_struct(\@tok, \$i, $j++, $file);
	push(@rv, $str) if ($str);
	}
return @rv;
}

# write_lines(file, line, ...)
# Writes a test file and clears the cached copy of it.
sub write_lines
{
my ($file, @lines) = @_;
open(my $out, '>', $file) or die $!;
print $out map { "$_\n" } @lines;
close($out);
delete($main::file_cache{$file});
delete($main::file_cache_noflush{$file});
}

subtest 'value checks' => sub {
	my @ok = ( [ 'pxelinux.0', 1 ], [ 'boot\134x64\134wdsnbp.com', 1 ],
		   [ 'a\\\\', 1 ], [ 'Name with spaces & <html>', 1 ],
		   [ '"a.com", "b.com"', 0 ], [ '10.0.0.1 , 10.0.0.2', 0 ],
		   [ '"a;b{c}#d"', 0 ], [ 'failover peer', 0 ],
		   [ '{', 0, 1 ], [ 'ip-address,', 0, 1 ] );
	foreach my $t (@ok) {
		ok(dh::directive_value_safe(@$t), "accepts $t->[0]");
		}
	my @bad = ( [ 'x"; } host evil { y', 1 ], [ 'x\\', 1 ],
		    [ '"x"; } host evil { "', 0 ], [ 'a;b', 0 ],
		    [ 'a#b', 0 ], [ '}', 0 ], [ '"a\\"', 0 ],
		    [ 'x } host evil {', 0, 0 ] );
	foreach my $t (@bad) {
		ok(!dh::directive_value_safe(@$t), "rejects $t->[0]");
		}
	};

subtest 'injected values are refused when writing' => sub {
	my $evil = 'x"; } host evil { hardware ethernet 00:11:22:33:44:55; '.
		   'fixed-address 10.0.0.9; } group { filename "y';
	my $ok = eval { dh::directive_lines({ 'name' => 'filename',
					      'values' => [ $evil ],
					      'quotes' => [ 1 ] }, 1); 1 };
	ok(!$ok, 'quoted filename with a quote is refused');
	like($@, qr/not allowed/, 'error explains the problem');
	$ok = eval { dh::directive_lines({ 'name' => 'option',
					   'values' => [ 'foo', "\"$evil\"" ] },
					 1); 1 };
	ok(!$ok, 'custom option value with a quote is refused');
	$ok = eval { dh::directive_lines({ 'name' => 'x; } host evil { allow',
					   'values' => [ 'unknown-clients' ] },
					 1); 1 };
	ok(!$ok, 'directive name with a semicolon is refused');
	my @lines = dh::directive_lines({ 'name' => 'filename',
					  'values' => [ 'pxelinux.0' ],
					  'quotes' => [ 1 ] }, 1);
	is_deeply(\@lines, [ "\tfilename \"pxelinux.0\";" ],
		  'normal quoted value is written unchanged');
	@lines = dh::directive_lines({ 'name' => 'option',
				       'values' => [ 'foo', 'code', '224', '=',
						     '{', 'ip-address,',
						     'string', '}' ] }, 0);
	is_deeply(\@lines, [ 'option foo code 224 = { ip-address, string };' ],
		  'option record types keep their braces');
	};

subtest 'multi-line comments are written as one line' => sub {
	my $file = "$tmp/dhcpd.conf";
	my $host = { 'name' => 'host', 'values' => [ 'printer' ],
		     'comment' => "Office printer\r\nsecond line\n",
		     'type' => 1,
		     'members' => [ { 'name' => 'fixed-address',
				      'values' => [ '10.0.0.5' ] } ] };
	my @lines = dh::directive_lines($host, 0);
	is($lines[0], '# Office printer second line', 'comment is one line');
	write_lines($file, @lines);
	my ($parsed) = parse_file($file);
	is($parsed->{'comment'}, 'Office printer second line',
	   'parser reads the whole comment back');

	# Saving again must not add more comment lines
	write_lines($file, dh::directive_lines($parsed, 0));
	($parsed) = parse_file($file);
	my @again = dh::directive_lines($parsed, 0);
	is_deeply(\@again, \@lines, 're-saving gives the same lines');
	is(scalar(grep { /^\s*#/ } @again), 1, 'comment lines do not pile up');
	};

subtest 'lease strings with escapes are tokenized like dhcpd' => sub {
	# dhcpd writes \ as \\ and " as \" inside strings
	my $name = 'a\\";} lease 10.6.6.6 { hardware ethernet <img src=x>; '.
		   'client-hostname "';
	(my $escaped = $name) =~ s/([\\"])/\\$1/g;
	my $file = "$tmp/dhcpd.leases";
	write_lines($file,
		    'lease 10.0.0.5 {',
		    '  starts 4 2026/11/18 10:00:00;',
		    '  hardware ethernet 00:11:22:33:44:55;',
		    "  client-hostname \"$escaped\";",
		    '}',
		    'lease 10.0.0.6 {',
		    '  client-hostname "plain\\\\";',
		    '}');
	my @leases = grep { $_->{'name'} eq 'lease' } parse_file($file);
	is_deeply([ map { $_->{'values'}->[0] } @leases ],
		  [ '10.0.0.5', '10.0.0.6' ],
		  'crafted client name cannot add a lease');
	my ($client) = grep { $_->{'name'} eq 'client-hostname' }
			    @{$leases[0]->{'members'}};
	like($client->{'values'}->[0], qr/^a\\134\\042;\} lease 10\.6\.6\.6/,
	     'escaped backslash and quote stay inside the string');
	my ($plain) = grep { $_->{'name'} eq 'client-hostname' }
			   @{$leases[1]->{'members'}};
	is($plain->{'values'}->[0], 'plain\\134',
	   'escaped backslash before the closing quote is kept');
	};

done_testing();
