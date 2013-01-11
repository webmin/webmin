#!/usr/local/bin/perl
# save_field.cgi
# Create, modify or delete a field

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&error_setup($text{'field_err'});

# Build default clause
if ($in{'default_def'} == 0) {
	$default = "default NULL";
	}
elsif ($in{'default_def'} == 2) {
	$default = "default CURRENT_TIMESTAMP";
	}
elsif ($in{'default_def'} == 3) {
	$default = $in{'new'} ? "" : "default ''";
	}
else {
	$default = "default '$in{'default'}'";
	}

if ($in{'delete'}) {
	# delete this field
	&execute_sql_logged($in{'db'},
		    "alter table ".&quotestr($in{'table'})." drop ".
		    &quotestr($in{'old'}));
	&webmin_log("delete", "field", $in{'old'}, \%in);
	}
elsif ($in{'new'}) {
	# add a new field
	$in{'field'} =~ /^\S+$/ || &error(&text('field_efield', $in{'field'}));
	$in{'null'} && $in{'key'} && &error($text{'field_ekey'});
	$in{'size'} = $size = &validate_size();
	$sql = sprintf "alter table %s add %s %s%s %s %s %s",
		&quotestr($in{'table'}), &quotestr($in{'field'}), $in{'type'},
		$size, $in{'null'} ? '' : 'not null',
		$default,
		$in{'ext'};
	&execute_sql_logged($in{'db'}, $sql);
	&webmin_log("create", "field", $in{'field'}, \%in);
	}
else {
	# modify an existing field
	$in{'field'} =~ /^\S+$/ || &error(&text('field_efield', $in{'field'}));
	$in{'null'} && $in{'key'} && &error($text{'field_ekey'});
	$in{'size'} = $size = &validate_size();
	$sql = sprintf "alter table %s modify %s %s%s %s %s %s",
			&quotestr($in{'table'}), &quotestr($in{'old'}),
			$in{'type'}, $size, $in{'null'} ? 'null' : 'not null',
			$default,
			$in{'ext'};
	&execute_sql_logged($in{'db'}, $sql);
	if ($in{'old'} ne $in{'field'} ||
	    $in{'type'} ne $in{'newtype'} ||
	    $in{'oldopts'} ne $in{'opts'}) {
		# Rename or retype field as well
		if ($in{'type'} ne $in{'newtype'} ||
		    $in{'oldopts'} ne $in{'opts'}) {
			# Type has changed .. fix size
			if ($in{'newtype'} eq 'enum' ||
			    $in{'newtype'} eq 'set') {
				# Convert old size to enum values
				if ($in{'type'} ne 'enum' &&
				    $in{'type'} ne 'set') {
					$size = $size =~ /^\((.*)\)/ ?
					    '('.join(",", map { "'$_'" }
						 split(/\n/, $1)).')' : "('')";
					}
				}
			elsif ($in{'newtype'} eq 'float' ||
			       $in{'newtype'} eq 'double' ||
			       $in{'newtype'} eq 'decimal') {
				# Use old sizes or size and opts
				$size = $size =~ /^\((\d+),(\d+)\)/ ? $size :
				  $size =~ /^\((\d+)\)(.*)/ ? "($1,$1)$2" : "";
				}
			elsif ($in{'newtype'} eq 'date' ||
			       $in{'newtype'} eq 'datetime' ||
			       $in{'newtype'} eq 'time' ||
			       $in{'newtype'} =~ /(blob|text)$/) {
				# New type has no size or opts
				$size = "";
				}
			else {
				# Use old size and opts
				$size = $size =~ /^\((\d+)/ ?
					"($1) $in{'opts'}" :
					$in{'newtype'} =~ /char$/ ?
					    "(255) $in{'opts'}" : $in{'opts'};
				}
			}
		$sql = sprintf "alter table %s change %s %s %s%s %s",
				&quotestr($in{'table'}), &quotestr($in{'old'}),
				&quotestr($in{'field'}), $in{'newtype'}, $size,
				$in{'null'} ? '' : 'not null';
		&execute_sql_logged($in{'db'}, $sql);
		}
	&webmin_log("modify", "field", $in{'field'}, \%in);
	}

if ($in{'key'} != $in{'oldkey'}) {
	# Adding or removing a primary key to the table
	foreach $d (&table_structure($in{'db'}, $in{'table'})) {
		push(@pri, $d->{'field'}) if ($d->{'key'} eq 'PRI');
		}
	if ($in{'key'}) {
		@npri = ( @pri, $in{'field'} );
		}
	else {
		@npri = grep { $_ ne $in{'field'} } @pri;
		}
	&execute_sql_logged($in{'db'},
		    "alter table ".&quotestr($in{'table'})." drop primary key")
		if (@pri);
	&execute_sql_logged($in{'db'},
		    "alter table ".&quotestr($in{'table'})." add primary key (".
		    join(",", map { &quotestr($_) } @npri).")") if (@npri);
	}
&redirect("edit_table.cgi?db=$in{'db'}&table=".&urlize($in{'table'}));

sub validate_size
{
if ($in{'type'} eq 'enum' || $in{'type'} eq 'set') {
	$in{'size'} || &error($text{'field_eenum'});
	$in{'size'} =~ s/\r//g;
	return '('.join(",", map { "'$_'" } split(/\n/, $in{'size'})).')';
	}
elsif ($in{'type'} eq 'float' || $in{'type'} eq 'double' ||
       $in{'type'} eq 'decimal') {
	$in{'size1'} =~ /^\d+$/ || &error(&text('field_esize', $in{'size1'}));
	$in{'size2'} =~ /^\d+$/ || &error(&text('field_esize', $in{'size2'}));
	return "($in{'size1'},$in{'size2'}) $in{'opts'}";
	}
elsif ($in{'type'} eq 'date' || $in{'type'} eq 'datetime' ||
       $in{'type'} eq 'time' || $in{'type'} eq 'timestamp' ||
       $in{'type'} =~ /(blob|text)$/) {
	return "";
	}
elsif ($in{'size_def'}) {
	return "";
	}
else {
	$in{'size'} =~ /^\d+$/ || &error(&text('field_esize', $in{'size'}));
	return "($in{'size'}) $in{'opts'}";
	}
}

