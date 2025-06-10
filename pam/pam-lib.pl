# pam-lib.pl
# Functions for manipulating the PAM services file(s)

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_pam_config()
# Returns a list of services and their modules
sub get_pam_config
{
local @rv;
local @ignore = split(/\s+/, $config{'ignore'});
opendir(DIR, &translate_filename($config{'pam_dir'}));
FILE: foreach $f (readdir(DIR)) {
	next if ($f =~ /^\./);
	foreach $i (@ignore) {
		next FILE if ($f =~ /^$i$/i);
		}
	local $serv = { 'name' => $f,
			'file' => "$config{'pam_dir'}/$f",
			'index' => scalar(@rv) };
	local $lnum = 0;
	&open_tempfile(FILE, $serv->{'file'});
	while(<FILE>) {
		s/\r|\n//g;
		if (/^\s*#+\s*description:\s*([A-Za-z].*)/i &&
		    !$serv->{'mods'}) {
			$serv->{'desc'} = $1;
			}
		s/#.*$//g;
		if (/^\s*\@include\s+(\S+)/) {
			# Special include line
			local $mod = { 'include' => $1,
				       'line' => $lnum,
				       'index' => @{$serv->{'mods'}}+0 };
			push(@{$serv->{'mods'}}, $mod);
			}
		elsif (/^\s*(\S+)\s+\[([^\]]*)\]\s+(\S+)\s*(.*)$/) {
			# Line with special rules .. ignore for now
			}
		elsif (/^\s*(\S+)\s+(\S+)\s+(\S+)\s*(.*)$/) {
			# Regular line
			local $mod = { 'type' => $1,   'control' => $2,
				       'module' => $3, 'args' => $4,
				       'line' => $lnum,
				       'index' => @{$serv->{'mods'}}+0 };
			push(@{$serv->{'mods'}}, $mod);
			}
		$lnum++;
		}
	&close_tempfile(FILE);
	push(@rv, $serv);
	}
closedir(DIR);
return @rv;
}

# create_module(service, &module)
# Add a PAM module to some service
sub create_module
{
local $lref = &read_file_lines("$config{'pam_dir'}/$_[0]");
push(@$lref, &module_line($_[1]));
&flush_file_lines();
}

# modify_module(service, &module)
# Update a PAM module in some service
sub modify_module
{
local $lref = &read_file_lines("$config{'pam_dir'}/$_[0]");
splice(@$lref, $_[1]->{'line'}, 1, &module_line($_[1]));
&flush_file_lines();
}

# delete_module(service, &module)
# Delete a PAM module from some service
sub delete_module
{
local $lref = &read_file_lines("$config{'pam_dir'}/$_[0]");
splice(@$lref, $_[1]->{'line'}, 1);
&flush_file_lines();
}

# swap_modules(service, &module1, &module2)
# Swap two PAM module entries in a service
sub swap_modules
{
local $lref = &read_file_lines("$config{'pam_dir'}/$_[0]");
local $line = $lref->[$_[1]->{'line'}];
$lref->[$_[1]->{'line'}] = $lref->[$_[2]->{'line'}];
$lref->[$_[2]->{'line'}] = $line;
&flush_file_lines();
}

# module_line(&module)
# Returns text for a PAM module line
sub module_line
{
if ($_[0]->{'include'}) {
	# Special include line
	return "\@include ".$_[0]->{'include'};
	}
else {
	# A regular module
	local $l = join("\t", $_[0]->{'type'}, $_[0]->{'control'},
			      $_[0]->{'module'});
	$l .= "\t$_[0]->{'args'}" if ($_[0]->{'args'});
	return $l;
	}
}

# list_modules()
# Returns a list of all PAM shared libraries
sub list_modules
{
local (@rv, %done, %hasmod);
foreach $d (map { glob($_) } split(/\s+/, $config{'lib_dirs'})) {
	opendir(DIR, &translate_filename($d));
	foreach $f (sort { $a cmp $b } readdir(DIR)) {
		local @st = stat(&translate_filename("$d/$f"));
		push(@rv, $f) if (!$done{$st[1]}++ && $f =~ /^pam_.*\.so$/);
		$hasmod{$f}++ if ($f =~ /^pam_.*\.so$/);
		}
	closedir(DIR);
	}
foreach $q (split(/\s+/, $config{'mod_equiv'})) {
	local ($q1, $q2) = split(/=/, $q);
	if ($hasmod{$q2}) {
		@rv = grep { $_ ne $q1 } @rv;
		}
	}
return sort { $a cmp $b } &unique(@rv);
}

# include_style(&pam)
# Returns 1 if includes are done with pam_stack.so, 2 if done with include
# lines, 3 if done with @include, 0 if not supported
sub include_style
{
local ($pam) = @_;
local @allmods = map { @{$_->{'mods'}} } @$pam;
local ($atinc) = grep { $_->{'include'} } @allmods;
local ($inc) = grep { $_->{'control'} eq 'include' } @allmods;
local ($stack) = grep { $_ eq "pam_stack.so" } &list_modules();
return $atinc ? 3 : $inc ? 2 : $stack ? 1 : 0;
}

1;

