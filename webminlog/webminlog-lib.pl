=head1 webminlog-lib.pl

This module contains functions for parsing the Webmin actions log file.

 foreign_require("webminlog", "webminlog-lib.pl");
 @actions = webminlog::list_webmin_log(undef, "useradmin", undef, undef);
 foreach $a (@actions) {
   print webminlog::get_action_description($a),"\n";
 }

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
%access_mods = map { $_, 1 } split(/\s+/, $access{'mods'});
%access_users = map { $_, 1 } split(/\s+/, $access{'users'});

=head2 list_webmin_log([only-user], [only-module], [start-time, end-time])

Returns an array of matching Webmin log events, each of which is a hash ref
in the format returned by parse_logline (see below). By default all actions
will be returned, but you can limit it to a subset using by setting the
following parameters :

=item only-user - Only return actions by this Webmin user.

=item only-module - Only actions in this module.

=item start-time - Limit to actions at or after this Unix time.

=item end-time - Limit to actions at or before this Unix time.

=cut
sub list_webmin_log
{
local ($onlyuser, $onlymodule, $start, $end) = @_;
local %index;
&build_log_index(\%index);
local @rv;
open(LOG, $webmin_logfile);
while(($id, $idx) = each %index) {
	local ($pos, $time, $user, $module, $sid) = split(/\s+/, $idx);
	next if (defined($onlyuser) && $user ne $onlyuser);
	next if (defined($onlymodule) && $module ne $onlymodule);
	next if (defined($start) && $time < $start);
	next if (defined($end) && $time > $end);
	seek(LOG, $pos, 0);
	my $line = <LOG>;
	my $act = &parse_logline($line);
	if ($act) {
		push(@rv, $act);
		}
	}
close(LOG);
return @rv;
}

=head2 parse_logline(line)

Converts a line of text in the format used in /var/webmin/webmin.log into
a hash ref containing the following keys :

=item time - Unix time the action happened.

=item id - A unique ID for the action.

=item user - The Webmin user who did it.

=item sid - The user's session ID.

=item ip - The IP address they were logged in from.

=item module - The Webmin module name in which the action was performed.

=item script - Relative filename of the script that performed the action.

=item action - A short action name, like 'create'.

=item type - The kind of object being operated on, like 'user'.

=item object - Name of the object being operated on, like 'joe'.

=item params - A hash ref of additional information about the action.

=cut
sub parse_logline
{
if ($_[0] =~ /^(\d+)\.(\S+)\s+\[.*\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+"([^"]+)"\s+"([^"]+)"\s+"([^"]+)"(.*)/ ||
    $_[0] =~ /^(\d+)\.(\S+)\s+\[.*\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(.*)/) {
	local $rv = { 'time' => $1, 'id' => "$1.$2",
		      'user' => $3, 'sid' => $4,
		      'ip' => $5, 'module' => $6,
		      'script' => $7, 'action' => $8,
		      'type' => $9, 'object' => $10 };
	local %param;
	local $p = $11;
	while($p =~ /^\s*([^=\s]+)='([^']*)'(.*)$/) {
		if (defined($param{$1})) {
			$param{$1} .= "\0".$2;
			}
		else {
			$param{$1} = $2;
			}
		$p = $3;
		}
	foreach $k (keys %param) {
		$param{$k} =~ s/%(..)/pack("c",hex($1))/ge;
		}
	$rv->{'param'} = \%param;
	if ($rv->{'script'} =~ /^(\S+):(\S+)$/) {
		$rv->{'script'} = $2;
		$rv->{'webmin'} = $1;
		}
	return $rv;
	}
else {
	return undef;
	}
}

=head2 list_diffs(&action)

Returns details of file changes made by this action. Each of which is a
hash ref with the keys :

=item type - The change type, such as create, modify, delete, exec, sql or kill.

=item object - The file or database the change was made to.

=item diff - A diff of the file change made.

=item input - Input to the command run, if available.

=cut
sub list_diffs
{
local $i = 0;
local @rv;
local $base = "$ENV{'WEBMIN_VAR'}/diffs/$act->{'id'}";
local @files = &expand_base_dir($base);

# Read the diff files
foreach my $file (@files) {
        local ($type, $object, $diff, $input);
	open(DIFF, $file);
        local $line = <DIFF>;
        while(<DIFF>) { $diff .= $_; }
        close(DIFF);
	if ($line =~ /^(\/.*)/) {
                $type = 'modify'; $object = $1;
                }
        elsif ($line =~ /^(\S+)\s+(.*)/) {
                $type = $1; $object = $2;
                }
	if ($type eq "exec") {
		open(INPUT, $file.".input");
		while(<INPUT>) {
			$input .= $_;
			}
		close(INPUT);
		}
	push(@rv, { 'type' => $type,
		    'object' => $object,
		    'diff' => $diff,
		    'input' => $input } );
	$i++;
	}
return @rv;
}

=head2 list_files(&action)

Returns details of original files before this action was taken. Each is a hash
ref containing keys :

=item type - One of create, modify or delete.

=item file - Full path to the file.

=item data - Original file contents, if any.

=cut
sub list_files
{
local $i = 0;
local @rv;
local $base = "$ENV{'WEBMIN_VAR'}/files/$act->{'id'}";
local @files = &expand_base_dir($base);
foreach my $file (@files) {
        local ($type, $object, $data);
	open(FILE, $file);
        local $line = <FILE>;
	$line =~ s/\r|\n//g;
        while(<FILE>) { $data .= $_; }
        close(FILE);
	if ($line =~ /^(\S+)\s+(.*)/) {
		$type = $1;
		$file = $2;
		}
	elsif ($line =~ /^\s+(.*)/) {
		$type = -1;
		$file = $1;
		}
	else {
		next;
		}
	push(@rv, { 'type' => $type,
		    'file' => $file,
		    'data' => $data });
	$i++;
	}
return @rv;
}

=head2 get_annotation(&action)

Returns the text of the log annotation for this action, or undef if none.

=cut
sub get_annotation
{
local ($act) = @_;
return &read_file_contents("$ENV{'WEBMIN_VAR'}/annotations/$act->{'id'}");
}

=head2 save_annotation(&action, text)

Updates the annotation for some action.

=cut
sub save_annotation
{
local ($act, $text) = @_;
local $dir = "$ENV{'WEBMIN_VAR'}/annotations";
local $file = "$dir/$act->{'id'}";
if ($text eq '') {
	unlink($file);
	}
else {
	&make_dir($dir, 0700) if (!-d $dir);
	&open_tempfile(ANNO, ">$file");
	&print_tempfile(ANNO, $text);
	&close_tempfile(ANNO);
	}
}

=head2 expand_base_dir(base)

Finds files either under some dir, or starting with some path in the same
directory.

=cut
sub expand_base_dir
{
local ($base) = @_;
local @files;
if (-d $base) {
	# Find files in the dir
	opendir(DIR, $base);
	@files = map { "$base/$_" } sort { $a <=> $b }
			grep { $_ =~ /^\d+$/ } readdir(DIR);
	closedir(DIR);
	}
else {
	# Files are those that start with id
	$i = 0;
	while(-r "$base.$i") {
		push(@files, "$base.$i");
		$i++;
		}
	}
return @files;
}

=head2 can_user(username)

Returns 1 if the current Webmin user can view log entries for the given user.

=cut
sub can_user
{
return $access_users{'*'} || $access_users{$_[0]};
}

=head2 can_mod(module)

Returns 1 if the current Webmin user can view log entries for the given module.

=cut
sub can_mod
{
return $access_mods{'*'} || $access_mods{$_[0]};
}

=head2 get_action(id)

Returns the structure for some action identified by an ID, in the same format 
as returned by parse_logline.

=cut
sub get_action
{
local %index;
&build_log_index(\%index);
local $act;
open(LOG, $webmin_logfile);
local @idx = split(/\s+/, $index{$_[0]});
seek(LOG, $idx[0], 0);
local $line = <LOG>;
local $act = &parse_logline($line);
close(LOG);
return $act->{'id'} eq $_[0] ? $act : undef;
}

=head2 build_log_index(&index)

Updates the given hash with mappings between action IDs and file positions.
For internal use only really.

=cut
sub build_log_index
{
local ($index) = @_;
local $ifile = "$module_config_directory/logindex";
dbmopen(%$index, $ifile, 0600);
local @st = stat($webmin_logfile);
if ($st[9] > $index->{'lastchange'}) {
	# Log has changed .. perhaps need to rebuild
	open(LOG, $webmin_logfile);
	if ($index->{'lastsize'} && $st[7] >= $index->{'lastsize'}) {
		# Gotten bigger .. just add new lines
		seek(LOG, $index->{'lastpos'}, 0);
		}
	else {
		# Smaller! Need to rebuild from start
		%$index = ( 'lastpos' => 0 );
		}
	while(<LOG>) {
		if ($act = &parse_logline($_)) {
			$index->{$act->{'id'}} = $index->{'lastpos'}." ".
						 $act->{'time'}." ".
						 $act->{'user'}." ".
						 $act->{'module'}." ".
						 $act->{'sid'};
			}
		$index->{'lastpos'} += length($_);
		}
	close(LOG);
	$index->{'lastsize'} = $st[7];
	$index->{'lastchange'} = $st[9];
	}
}

=head2 get_action_description(&action, [long])

Returns a human-readable description of some action. This is done by
calling the log_parser.pl file in the action's source module. If the long
parameter is set to 1 and the module provides a more detailed description
for the action, it will be returned.

=cut
sub get_action_description
{
local ($act, $long) = @_;
if (!defined($parser_cache{$act->{'module'}})) {
	# Bring in module parser library for the first time
	if (-r "$root_directory/$act->{'module'}/log_parser.pl") {
		&foreign_require($act->{'module'}, "log_parser.pl");
		$parser_cache{$act->{'module'}} = 1;
		}
	else {
		$parser_cache{$act->{'module'}} = 0;
		}
	}
local $d;
if ($parser_cache{$act->{'module'}}) {
	$d = &foreign_call($act->{'module'}, "parse_webmin_log",
			   $act->{'user'}, $act->{'script'},
			   $act->{'action'}, $act->{'type'},
			   $act->{'object'}, $act->{'param'}, $long);
	}
return $d ? $d :
       $act->{'action'} eq '_config_' ? $text{'search_config'} :
		join(" ", $act->{'action'}, $act->{'type'}, $act->{'object'});
}

1;

