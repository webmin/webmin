#!/usr/bin/perl
# Check SpamAssassin config file access and the values written to config files.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$FindBin::Bin/test-lib.pl";
*main::error = sub { die join(' ', @_)."\n" };

# load_subs(file, name, ...)
# Loads only the named functions from a module library, without its setup code
sub load_subs
{
# The loaded code must not see lexicals from here, so they are not used
my $source = read_text("$root/".shift(@_));
foreach (@_) {
	$source =~ /(^sub \Q$_\E\n\{.*?^\}\n)(?=\n*(?:#|sub |1;|\z))/ms ||
		die "Missing $_";
	eval_sub($1);
	}
}

# eval_sub(code)
# Compiles one function in package main
sub eval_sub
{
eval 'no strict; no warnings; '.$_[0];
die $@ if ($@);
}
load_subs("spam/spam-lib.pl", qw(set_config_file can_edit_any_config_file
	can_use_page save_directives make_directives alt_name find));
load_subs("spam/spam-amavis-lib.pl", qw(get_amavis_config check_amavis_value
	amavis_quote_value save_amavis_directive amavis_find perl_unescape));
%main::text = ( 'index_ecannot' => 'Cannot use $1',
		'save_eline' => 'Line break in setting',
		'amavis_eline' => 'Line break in Amavisd setting' );
%main::module_info = ( );
my $tmp = tempdir(CLEANUP => 1);
%main::config = ( 'local_cf' => "$tmp/local.cf" );
my $domain_cf = "$tmp/spam/123/virtualmin.cf";

# can_set(&access, file)
# Returns 1 if set_config_file accepts a file for a user with some ACL
sub can_set
{
my ($acl, $file) = @_;
local %main::access = %$acl;
return eval { main::set_config_file($file); 1 } ? 1 : 0;
}

subtest 'config file choice follows the ACL' => sub {
	my $full = 'white,score,report,user,header,priv,setup,procmail,db,awl,manual';
	is(can_set({ 'avail' => $full }, $domain_cf), 1,
	   'master admin can open a per-domain file');
	is(can_set({ 'avail' => 'white,header', 'noconfig' => 1 }, $domain_cf), 0,
	   'limited user without a file setting is refused other files');
	is(can_set({ 'avail' => 'white,header', 'noconfig' => 1 },
		   $main::config{'local_cf'}), 1,
	   'limited user can still use the default file');
	is(can_set({ 'avail' => 'white,manual', 'noconfig' => 1 }, $domain_cf), 1,
	   'manual editing allows other files');
	is(can_set({ 'avail' => 'white,header' }, $domain_cf), 1,
	   'module config access allows other files');
	my %domain = ( 'avail' => $full, 'file' => $domain_cf,
		       'files' => "$domain_cf $tmp/spam/456/virtualmin.cf" );
	is(can_set(\%domain, "$tmp/spam/456/virtualmin.cf"), 1,
	   'domain owner can open another listed file');
	is(can_set(\%domain, "/etc/shadow"), 0,
	   'domain owner is refused other files even with full features');
	};

subtest 'directives cannot contain line breaks' => sub {
	write_text($main::config{'local_cf'}, "required_score 5\n");
	local $main::local_cf = $main::config{'local_cf'};
	local $main::add_cf = $main::local_cf;
	my $conf = [ ];
	ok(!eval { main::save_directives($conf, 'describe',
			[ "TEST x\nloadplugin Evil /tmp/evil.pm" ], 1); 1 },
	   'newline in a value is refused');
	like($@, qr/Line break in setting/, 'with the expected error');
	ok(eval { main::save_directives($conf, 'describe',
			[ 'TEST Some test' ], 1); 1 }, 'normal value is saved')
		or diag($@);
	main::flush_file_lines();
	like(read_text($main::local_cf), qr/^describe TEST Some test$/m,
	     'value written on one line');
	};

subtest 'Amavisd values cannot inject Perl code' => sub {
	ok(main::check_amavis_value('6.31', 1), 'number accepted');
	ok(main::check_amavis_value('10*1024*1024', 1), 'arithmetic accepted');
	ok(main::check_amavis_value('200 * 1024', 1), 'spaced arithmetic accepted');
	ok(!main::check_amavis_value('200 1024', 1), 'missing operator refused');
	ok(main::check_amavis_value('undef', 1), 'undef accepted');
	ok(!main::check_amavis_value('6;system("id")', 1), 'code refused');
	ok(!main::check_amavis_value('undef;1', 1), 'suffix after undef refused');
	ok(!main::check_amavis_value('*', 1), 'value without digits refused');
	ok(!main::check_amavis_value("x\ny"), 'newline refused');

	my $file = "$tmp/amavisd.conf";
	write_text($file, "\$sa_tag2_level_deflt = 6.31;\n".
			  "\$sa_spam_subject_tag = '***SPAM*** ';\n".
			  "\$sa_mail_body_size_limit = (200 * 1024); # bytes\n1;\n");
	local $main::config{'amavisdconf'} = $file;
	my $conf = main::get_amavis_config();
	my $evil = '"; $main::pwned = 1; "@{[ $main::pwned = 1 ]}\\';
	main::save_amavis_directive($conf, 'sa_spam_subject_tag', $evil);
	main::save_amavis_directive($conf, 'sa_tag2_level_deflt', '6;$x=1');
	main::save_amavis_directive($conf, 'sa_kill_level_deflt', '9.5');
	main::save_amavis_directive($conf, 'sa_mail_body_size_limit', '(200 * 1024)');
	main::flush_file_lines();

	# Evaluate the written file, which must only assign the given values
	my $code = read_text($file);
	like($code, qr/^\$sa_mail_body_size_limit = \(200 \* 1024\); # bytes$/m,
	     'unchanged expression and comment survive an unrelated edit');
	our ($sa_spam_subject_tag, $sa_tag2_level_deflt, $sa_kill_level_deflt);
	local $main::pwned;
	ok(eval "no strict; package main; $code; 1", 'file is valid Perl')
		or diag($@);
	ok(!$main::pwned, 'no injected code ran');
	is($sa_spam_subject_tag, $evil, 'string value saved literally');
	is($sa_tag2_level_deflt, '6;$x=1', 'non-numeric value quoted');
	is($sa_kill_level_deflt, 9.5, 'new numeric value saved');
	};

done_testing();
