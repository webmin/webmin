#!/usr/local/bin/perl

require './filemin-lib.pl';
use Cwd 'abs_path';

&ReadParse(\%in, "GET");

get_paths();

my @errors;
my @uploaded_files;
my $uploaded_dir;
$line = "";

# Use Webmin's callback function to track progress
$cbfunc = \&read_parse_mime_callback;

# Get multipart form boundary
$ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/ || &error($text{'readparse_enc'});
$boundary = $1;

# Initialize progress tracker
&$cbfunc(0, $ENV{'CONTENT_LENGTH'}, undef, $in{'id'});

#Read the data
MAINLOOP: while(index($line,"$boundary--") == -1) {
	# Reset vars on each loop
	$file = undef;
	$rest = undef;
	$prevline = undef;
	$header = undef;
	$line = <STDIN>;
	$got += length($line);
	if ($upload_max && $got > $upload_max) {
		&error(&text('error_upload_emax', &nice_size($upload_max)));
		}
  	&$cbfunc($got, $ENV{'CONTENT_LENGTH'}, undef, $in{'id'});
	if ($line =~ /(\S+):\s*form-data(.*)$/) {
		$rest = $2; # We found form data definition, let`s check it
		}
	else {
		next;
		}

	# Check if current form data part is file
	while ($rest =~ /([a-zA-Z]*)=\"([^\"]*)\"(.*)/) {
		if ($1 eq 'filename') {
			$file = $2;
			}
		$rest = $3;
		}
    
	if (defined($file)) {
		my @st = stat($cwd);
		# If we have a dir, parse it and create a sub-tree first
		if ($file =~ /\//) {
			my ($dir) = $file =~ /^(.*)\/[^\/]+$/;
			if ($dir) {
				my @dirs = split('/', $dir);
				$dir = '/';
				# If overwriting is not allowed check for dupes
				if (!$in{'overwrite_existing'}) {
					if ($dirs[0] && -e "$cwd/$dirs[0]") {
						# As only one directory upload at a time allowed
						# check if parent exists and if it does add
						# predictable suffix, like `dir(1)` or `dir(2)`
						if (!$uploaded_dir) {
							my $__ = 1;
							for (;;) {
							    my $new_dir_name = "$dirs[0](" . $__++ . ")";
							    if (!-e "$cwd/$new_dir_name") {
									$uploaded_dir = $new_dir_name;
							        last;
							    	}
								}
							}
						}
					else {
						$uploaded_dir = $dirs[0];
						}
					$file =~ s/^(\Q$dirs[0]\E)/$uploaded_dir/;
					$dirs[0] = $uploaded_dir;
				}
				foreach my $updir (@dirs) {
					$dir .= "$updir/";
					if (!-e "$cwd$dir") {
						mkdir("$cwd$dir");
						&set_ownership_permissions($st[4], $st[5], undef, "$cwd$dir");
						}
					}
				}
			}
		# In case of a regular file check for dupes
		if (!$in{'overwrite_existing'}) {
			if ($file && -e "$cwd/$file") {
				# If file exists add predictable suffix, like `file(1)` or `file(2)`
				my ($file_name, $file_extension) = $file =~ /(?|(.*)\.((?|tar|wbm|wbt)\..*)|(.*)\.([a-zA-Z]+\.(?|gpg|pgp))|(.*)\.(?=(.*))|(.*)())/;
				$file_extension  = ".$file_extension" if ($file_extension);
				my $__ = 1;
				for (;;) {
					my $new_file_name = "$file_name(" . $__++ . ")";
					if (!-e "$cwd/$new_file_name$file_extension") {
						$file = "$new_file_name$file_extension";
						last;
						}
					}
				}
			}

		# OK, we have a file, let`s save it
		my $full = "$cwd/$file";
		my $newfile = !-e $full;
		if (!open(OUTFILE, ">$full")) {
			push @errors, "$text{'error_opening_file_for_writing'} $path/$file - $!";
			next;        
			}
		else {
			binmode(OUTFILE);
			if ($newfile) {
				# Copy ownership from parent dir
				&set_ownership_permissions($st[4], $st[5], undef, $full);
				}
			# Skip "content-type" as we work in binmode anyway and
			# skip empty line
			<STDIN>;
			<STDIN>;

			# Read all lines until next boundary or form data end
			while(1) {
				$line = <STDIN>;
				if (!defined($line)) {
			    		push @errors, "Unexpected end of input";
					last MAINLOOP;
			        }
			        # Inform progress tracker about our actions
			      	$got += length($line);
		      		&$cbfunc($got, $ENV{'CONTENT_LENGTH'}, $file, $in{'id'});

			      	# Some brainf###ing to deal with last CRLF
              			if (index($line,"$boundary") != -1 ||
				    index($line,"$boundary--") != -1) {
			  		chop($prevline);
			  		chop($prevline);
                  			if (!print OUTFILE $prevline) {
                      				push @errors, "text{'error_writing_file'} $path/$file";
		      				last MAINLOOP;
                  				}
					last;
					}
				else {
                  			if (!print OUTFILE $prevline) {
						push @errors, "text{'error_writing_file'} $path/$file";
				      		last MAINLOOP;
						}
					$prevline = $line;
					}
				}

          		# File saved, let`s go further
          		close(OUTFILE);

          		# Store which file were uploaded
          		my $fpath = $cwd;
          		my $ffile = $file;
          		my @subdirs = split('/', $ffile);
          		if (@subdirs > 1) {
          			$ffile = pop(@subdirs);
          			$fpath .= ("/" . join('/', @subdirs));
          			}
          		push(@uploaded_files, {'path' => $fpath, 'file' => $ffile});
      			}
		}
	else {
		# Just skip everything until next boundary or form end
		while (index($line, "$boundary") == -1 ||
		       index($line, "$boundary--") == -1) {
			$line = <STDIN>;
			}        
		}
	}

# Extract and delete uploaded files
if ($in{'extract_uploaded'}) {
	my @eerrors = &extract_files(\@uploaded_files, 1);
	@errors = (@eerrors, @errors)
		if (@eerrors);
	}

# Everything finished, inform progress tracker
&$cbfunc(-1, $ENV{'CONTENT_LENGTH'}, undef, $in{'id'});
if (scalar(@errors) > 0) {
	print_errors(@errors);
	}
else {
	&redirect("index.cgi?path=".&urlize($path));
	}