#!/usr/local/bin/perl
# save_recipe.cgi
# Create, update or delete a procmail recipe

require './procmail-lib.pl';
&ReadParse();
&lock_file($procmailrc);
@conf = &get_procmailrc();
$rec = $conf[$in{'idx'}] if (!$in{'new'});

if ($in{'delete'}) {
	# Just delete the recipe
	&delete_recipe($rec);
	}
else {
	# Validate inputs
	&error_setup($text{'save_err'});
	if ($in{'block'}) {
		# Conditional code block
		$in{'bdata'} =~ s/\r//g;
		$rec->{'block'} = $in{'bdata'};
		}
	else {
		# Normal action
		$in{'action'} =~ /\S/ ||
			&error($text{'save_eaction_'.$in{'amode'}});
		delete($rec->{'type'});
		if ($in{'amode'} == 0) {
			$rec->{'action'} = $in{'action'};
			}
		elsif ($in{'amode'} == 1) {
			$rec->{'action'} = $in{'action'}."/.";
			}
		elsif ($in{'amode'} == 2) {
			$rec->{'action'} = $in{'action'}."/";
			}
		elsif ($in{'amode'} == 3) {
			$rec->{'type'} = "!";
			$rec->{'action'} = $in{'action'};
			}
		elsif ($in{'amode'} == 6) {
			$rec->{'type'} = "=";
			$in{'action'} =~ /^(\S+)=(.*)$/ ||
				&error($text{'save_eactionvar'});
			$rec->{'action'} = $in{'action'};
			}
		else {
			$rec->{'type'} = "|";
			$rec->{'action'} = $in{'action'};
			}
		}

	map { $flag{$_}++ } split(/\0/, $in{'flag'});
	@flags = @{$rec->{'flags'}};
	foreach $f (@known_flags) {
		if ($flag{$f}) {
			push(@flags, $f);
			}
		else {
			@flags = grep { $_ ne $f } @flags;
			}
		}
	$rec->{'flags'} = [ &unique(@flags) ];

	if ($in{'lockfile_def'} == 1) {
		delete($rec->{'lockfile'});
		}
	elsif ($in{'lockfile_def'} == 2) {
		$rec->{'lockfile'} = "";
		}
	else {
		$in{'lockfile'} =~ /\S/ || &error($text{'save_elockfile'});
		$rec->{'lockfile'} = $in{'lockfile'};
		}

	for($i=0; defined($m = $in{"cmode_$i"}); $i++) {
		next if ($m eq '-');
		$c = $in{"cond_$i"};
		if ($m eq '<' || $m eq '>') {
			$c =~ /^\d+$/ || &error(&text('save_esize', $i+1));
			}
		elsif ($m eq '$' || $m eq '?') {
			$c =~ /\S/ || &error(&text('save_eshell', $i+1));
			}
		else {
			$c =~ /\S/ || &error(&text('save_ere', $i+1));
			}
		push(@conds, [ $m, $c ]);
		}
	$rec->{'conds'} = \@conds;

	# Save the receipe
	if ($in{'new'}) {
		if ($in{'before'} ne '') {
			$before = $conf[$in{'before'}];
			&create_recipe_before($rec, $before);
			}
		elsif ($in{'after'} ne '') {
			if ($in{'after'} == @conf-1) {
				&create_recipe($rec);
				}
			else {
				$before = $conf[$in{'after'}+1];
				&create_recipe_before($rec, $before);
				}
			}
		else {
			&create_recipe($rec);
			}
		}
	else {
		&modify_recipe($rec);
		}
	}
&unlock_file($procmailrc);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "recipe", undef, $rec);
&redirect("");

