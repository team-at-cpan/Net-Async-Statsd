package Net::Async::Statsd;
# ABSTRACT: IO::Async support for statsd/graphite
use strict;
use warnings;

use parent qw(IO::Async::Notifier);

our $VERSION = '0.001';

=head1 NAME

Net::Async::Statsd - asynchronous API for Etsy's statsd protocol

=head1 SYNOPSIS

 use Future;
 use IO::Async::Loop;
 use Net::Async::Statsd;
 my $loop = IO::Async::Loop->new;
 $loop->add(my $statsd = Net::Async::Statsd->new(
   host => 'localhost',
   port => 3001,
 ));
 Future->needs_all(
  $statsd->timing(
   'some.task' => 133,
  ),
  $statsd->gauge(
   'some.value' => 80,
  )
 )->get;

=head1 DESCRIPTION

Provides an asynchronous API for statsd.

=head1 METHODS

All public methods return a L<Future> indicating when the write has completed.
Since writes are UDP packets, there is no guarantee that the remote will
receive the value, so this is mostly intended as a way to detect when
statsd writes are slow.

=cut

=head2 timing

Records timing information in milliseconds. Takes two parameters:

=over 4

=item * $k - the statsd key

=item * $v - the elapsed time in milliseconds

=item * $rate - optional sampling rate

=back

Only the integer part of the elapsed time will be sent.

Example usage:

 $statsd->timing('some.key' => $ms, $rate);

Returns a L<Future> which will be resolved when the write completes.

=cut

sub timing {
	my ($self, $k, $v, $rate) = @_;

	$self->queue_stat(
		$k => int($v) . '|ms',
		$rate
	);
}

=head2 gauge

Records timing information in milliseconds. Takes two parameters:

=over 4

=item * $k - the statsd key

=item * $v - the elapsed time in milliseconds

=item * $rate - optional sampling rate

=back

Only the integer part of the elapsed time will be sent.

Example usage:

 $statsd->timing('some.key' => $ms, $rate);

Returns a L<Future> which will be resolved when the write completes.

=cut

sub gauge {
	my ($self, $k, $v, $rate) = @_;

	$self->queue_stat(
		$k => int($v) . '|g',
		$rate
	);
}

=head2 delta

Records timing information in milliseconds. Takes two parameters:

=over 4

=item * $k - the statsd key

=item * $v - the elapsed time in milliseconds

=item * $rate - optional sampling rate

=back

Only the integer part of the elapsed time will be sent.

Example usage:

 $statsd->timing('some.key' => $ms, $rate);

Returns a L<Future> which will be resolved when the write completes.

=cut

sub delta {
	my ($self, $k, $v, $rate) = @_;

	$self->queue_stat(
		$k => int($v) . '|c',
		$rate
	);
}

=head2 increment

=cut

sub increment {
	my ($self, $k, $rate) = @_;

	$self->queue_stat(
		$k => '1|c',
		$rate
	);
}

sub decrement {
	my ($self, $k, $rate) = @_;

	$self->queue_stat(
		$k => '-1|c',
		$rate
	);
}

=head1 INTERNAL METHODS

These methods are used internally, and are documented
for completeness. They may be of use when subclassing
this module.

=cut

sub queue_stat {
	my ($self, $k, $v, $rate) = @_;

	$rate //= $self->default_rate;
	return Future->wrap unless $self->sample($rate);

	# Append rate if we're only sampling part of the data
	$v .= '|@' . $rate if $rate < 1;
	$self->statsd->write(
		"$k:$v"
	)
}

sub sample {
	my ($self, $rate) = @_;
	return 1 if rand <= $rate;
	return 0;
}

=head2 default_rate

Default sampling rate. Currently hardcoded to 1.

=cut

sub default_rate { 1 }

=head2 connect

Establishes the underlying UDP socket.

=cut

sub connect {
	my ($self) = @_;
	# IO::Async::Loop
	$self->loop->connect(
		family    => 'inet',
		socktype  => 'dgram',
		service   => $self->port,
		host      => $self->host,
		on_socket => $self->curry::on_socket,
	);
}

=head2 on_socket

Called when the socket is established.

=cut

sub on_socket {
	my ($self, $sock) = @_;
	$self->debug_printf("UDP socket established: %s", $sock->write_handle->sockhost_service);
	$sock->configure(
		on_recv       => $self->curry::weak::on_recv,
		on_recv_error => $self->curry::weak::on_recv_error,
	);
	$self->add_child($sock);
}

=head2 on_recv

Called if we receive data.

=cut

sub on_recv {
	my ($self, undef, $dgram, $addr) = @_;
	$self->debug_printf("UDP packet received from %s", join ':', $self->loop->resolver->getnameinfo(
		addr    => $addr,
		numeric => 1,
		dgram   => 1,
	));
}

=head2 on_recv_error

Called if we had an error while receiving.

=cut

sub on_recv_error {
	my ($self, undef, $err) = @_;
	$self->debug_printf("UDP packet receive error: %s", $err);
}

1;

__END__

=head1 SEE ALSO

=over 4

=item * L<Net::Statsd> - synchronous implementation

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2014. Licensed under the same terms as Perl itself.

