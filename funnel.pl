#!/usr/bin/perl

# By Larry Clapp, larry@theclapp.org
#
# Last updated: Thu Feb 14 22:42:54 EST 2002 
#
# spawn() adapted from the function of the same name in Expect.pm.  Docs for
# IO::Pty leave a lot to be desired, esp. if you haven't fiddled with ttys
# before.

use IO::Pty;                    # This appears to require 5.004
use Term::ReadLine;

use POSIX;                      # For setsid. 
use Fcntl;                      # For checking file handle settings.

sub spawn
{
  my( $tty, $name_of_tty );

  # Create the pty which we will use to pass process info.
  my($self) = new IO::Pty;

  # spawn is passed command line args.
  my(@cmd) = @_;

  $name_of_tty = $self->IO::Pty::ttyname();
  die "Could not assign a pty" 
      unless $name_of_tty;
  $self->autoflush();

  $pid = fork();
  unless (defined( $pid )) {
    warn "Cannot fork: $!";
    return undef;
  }
  unless ($pid) {
    # Child
    # Create a new 'session', lose controlling terminal.
    POSIX::setsid() 
	or warn "Couldn't perform setsid. Strange behavior may result.\r\n  Problem: $!\r\n";
    $tty = $self->IO::Pty::slave(); # Create slave handle.

    # We have to close everything and then reopen ttyname after to get a
    # controlling terminal.
    close($self);
    close STDIN; close STDOUT;
    open(STDIN,"<&". $tty->fileno()) || die "Couldn't reopen ". $name_of_tty ." for reading, $!\r\n";
    open(STDOUT,">&". $tty->fileno()) || die "Couldn't reopen ". $name_of_tty ." for writing, $!\r\n";

    # put this here or we would never see those die's above...
    close STDERR;
    open(STDERR,">&". $tty->fileno()) || die "Couldn't redirect STDERR, $!\r\n";

    exec (@cmd);
#    open(STDERR,">&2");
    die "Cannot exec `@cmd': $!\n";
    # End Child.
  }

  # sleep 1/4 second; allow child to start
  # select( undef, undef, undef, 0.25 );

  return $self;
}



sub process_readline_data2
{
    print "got a line\n"
	if $debug;
    $lineread2 = $_[ 0 ];
    $got_a_line2 = 1; 				# global

    &uninstall_handler();
}


sub check_tty_data
{
    my( $tty_read, $rout, @bits, $n, $l );

    # poll tty
    $n = select( $rout = $tty_rin, undef, undef, 0 );

    if ($n)
    {
	# print ( "\nreading from spawned tty ...\n" );
	$tty_read = sysread( $master, $l, 10240 );
	if ($tty_read)
	{
	    print "$tty_read bytes read from tty\n"
		if $debug;

	    if ($stdin_data)
	    {
		print "stdin_data is >$stdin_data<\n",
		    "tty_data is >$l<\n"
			if $debug;

		$stdin_data =~ s/[\r\n]+$//;
		if ($l =~ /(\Q$stdin_data\E[\r\n]*)/)
		{
		    $match = $1;
		    print "Deleting >$match< from tty_data\n"
			if $debug;
		    $l =~ s/\Q$match\E//;

		    $stdin_data = undef;
		}
		else
		{
		    print "tty data doesn't match stdin_data\n"
			if $debug;
		}
	    }
	    else
	    {
		print "no stdin data\n"
		    if $debug;
	    }

	    print $l;
	    $tty_data = $l;

	    if ($tty_data !~ /[\r\n]$/)
	    {
		$tty_data =~ /\n?([^\r\n]*)$/;
		$last_partial_line = $1;
		if ($last_partial_line eq '')
		{
		    print "resetting last_partial_line\n"
			if $debug3;
		    $last_partial_line = undef;
		}
		else
		{
		    print "last partial line is >$last_partial_line<\n"
			if $debug3;
		}
	    }
	}
	else
	{
	    $tty_open = 0;
	    if (defined( $tty_read ))
	    {
		print "sysread of tty returned 0\n";
	    }
	    else
	    {
		print "sysread of tty returned undef\n";
		print "error code is $!\n";
	    }
	}
    }
    else
    {
	print "nothing read from tty\n"
	    if $debug;
    }

    return( $tty_read );
}

sub check_pipe_data
{
    my( $pipe_read, $rout, @bits, $n, $l );

    # poll fifo
    $n = select( $rout = $pipe_rin, undef, undef, 0 );

    if ($n)
    {
	print ( "\nreading from pipe ...\n" )
	    if $debug;
	$pipe_read = sysread( PIPE, $l, 10240 );
	if ($pipe_read)
	{
	    print "$pipe_read bytes read from pipe\n"
		if $debug;

	    print $master $l;
	    $pipe_data = $l;
	}
	else
	{
	    print "sysread on pipe returned 0\n";
	    print $master "(quit)\n";
	    $pipe_open = 0;
	}
    }
    else
    {
	print "nothing read from pipe\n"
	    if $debug;
    }

    return( $pipe_read );
}

sub install_handler
{
    if (defined( $last_partial_line ))
    {
	print "Installing handler with prompt >$last_partial_line<\n",
	    "resetting last_partial_line\n"
	    if $debug3;
	$rl->{already_prompted} = 1;
	$rl->callback_handler_install( $last_partial_line, \&process_readline_data2 );
	$handler_installed = 1;
	$told_readline = 1;
	$last_partial_line = undef;
    }
    else
    {
	print "Installing handler with no prompt\n"
	    if $debug3;
	$rl->{already_prompted} = 0;
	$rl->callback_handler_install( '', \&process_readline_data2 );
	$handler_installed = 1;
	$told_readline = 0;
    }
}

sub uninstall_handler
{
    print "Uninstalling handler\n"
	if $debug3;
    $rl->callback_handler_install( '', undef );
    $handler_installed = 0;
}


sub check_stdin_data
{
    my( $stdin_read, $rout, @bits, $n );

    if ($handler_installed)
    {
	if ($last_partial_line
	    && !$told_readline)
	{
	    print "Telling readline on new line; resetting last_partial_line\n"
		if $debug3;
	    $told_readline = 1;
	    $rl->set_prompt( $last_partial_line );
	    $rl->on_new_line_with_prompt;
	    $last_partial_line = undef;
	}

	# poll stdin
	$n = select( $rout = $stdin_rin, undef, undef, 0 );

	if ($n)
	{
	    # process the character
	    $rl->callback_read_char();
	}
    }
    else
    {
	&install_handler();
    }

    # process the line *after* you process the character, if any
    if ($got_a_line2)
    {
	$got_a_line2 = 0;
	if (defined( $lineread2 ))
	{
	    # $lineread .= "\n";
	    print $master $lineread2, "\n";
	    $stdin_data = $lineread2;
	    $stdin_read = length( $stdin_data );

	    $lineread2 =~ s/[\r\n]+//;
	    if ($lineread2 ne '')
	    {
		print "Adding history >$lineread2<\n"
		    if $debug2;
		$rl->AddHistory( $lineread2 );
		if ($debug2)
		{
		    printf "where_history is %d\n", $rl->where_history;
		    foreach $f ($rl->GetHistory)
		    {
			printf( "History is %s ", $f );
		    }
		}
	    }
	}
	else
	{
	    print "readline on stdin returned empty line\n";
	    $stdin_open = 0;
	}
    }

    return( $stdin_read );
}


# timeout in seconds
$timeout = 0.05;

$debug = 0;
$debug2 = 0;
$debug3 = 0;

$pipe_name = shift @ARGV;

if (! -e $pipe_name)
{
    system( "mkfifo -m go-rwx $pipe_name" );
}
elsif (! -p $pipe_name)
{
    print STDERR "$pipe_name exists, and is not a fifo\n";
    exit( 1 );
}

$writer_pid = fork();
if (0 == $writer_pid)
{
    # child

    # Open it for output, so the open-for-input call doesn't block.  This allows
    # any other process to just open it, write to it, and close it, and we don't
    # have to worry about it closing due to lack of writers.
    open( PIPE_OUT, ">$pipe_name" ) or die "couldn't open pipe for output: $!";

    # sleep for a year
    sleep( 3600 * 24 * 365 );
    exit;
}

# don't need to sleep to wait for above child -- the OS will block us until
# the child opens the pipe
open( PIPE, "<$pipe_name" ) or die "couldn't open fifo '$pipe_name': $!";

select( PIPE ); $| = 1;
select( STDOUT ); $| = 1;

$last_partial_line = undef;
$tty_open = 1;
$pipe_open = 1;
$stdin_open = 1;

$master = &spawn( @ARGV );
print "spawned @ARGV\n"
    if $debug;

$tty_rin = '';   vec( $tty_rin, $master->fileno(), 1 ) = 1;
$pipe_rin = '';  vec( $pipe_rin, fileno( PIPE ), 1 ) = 1;
$stdin_rin = ''; vec( $stdin_rin, fileno( STDIN ), 1 ) = 1;

$rl = new Term::ReadLine 'funnel';
$rl->prep_terminal( 0 );
$attribs = $rl->Attribs;
$rl->using_history();

if ($debug)
{
    @features = keys %{ $rl->Features };
    print "ReadLine features: @features\n";
}

&install_handler();

$rin_all = '';
vec( $rin_all, $master->fileno(), 1 ) = 1;
vec( $rin_all, fileno( PIPE ), 1 ) = 1;
vec( $rin_all, fileno( STDIN ), 1 ) = 1;

while ($tty_open
       && $pipe_open
       && $stdin_open)
{
    $tty_read = &check_tty_data();
    $pipe_read = &check_pipe_data();
    $stdin_read  = &check_stdin_data();

    if (!$tty_read
	&& !$pipe_read
	&& !$stdin_read
	&& $tty_open
	&& $pipe_open
	&& $stdin_open)
    {
	# wait for *any* data
	print "waiting for any data\n"
	    if $debug;
	$n = select( $rout = $rin_all, undef, undef, undef );
    }
}

print "Signaling writer\n"
    if $debug;
kill 2, $writer_pid;
$rc = wait();
print "wait returned $rc\n"
    if $debug;

# FIXME: probably need to do something to close down the tty, but I don't know
# exactly what

# delete the fifo
unlink( $pipe_name );

