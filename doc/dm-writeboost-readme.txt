dm-writeboost
=============
dm-writeboost target provides block-level log-structured caching.
All writes and reads are written to the caching device in sequential manner.


Mechanism
=========
Control three layers (RAM buffer, caching device and backing device)
--------------------------------------------------------------------
dm-writeboost controls three different layers - RAM buffer (rambuf), caching
device (cache_dev, e.g SSD) and backing device (backing_dev, e.g. HDD).
All data are first stored in the RAM buffer and when the RAM buffer is full,
dm-writeboost adds metadata block (with checksum) on the RAM buffer to create a
"log". Afterward, the log is written to the caching device sequentially by a
background thread and thereafter written back to the backing device in the
background as well.


dm-writeboost vs dm-cache or bcache
===================================
How dm-writeboost differs from other existing SSD-caching drivers?

The most distinctive point is that dm-writeboost writes to caching device the
least frequently. Because it creates a log that's contains 127 writes before
it actually writes the log to the caching device, writing to the caching device
happens only once in 127 writes while other caching drivers writes more often.
Since SSD's lifetime decreases as it experiences writes, users can reduce the
risk of SSD disorder.

dm-writeboost performs very much efficient than other caching solutions in
small random pattern. But since it always split the requests into 4KB chunks,
it may not be the best when the ave. I/O size is very large in your workload.
However, if the splitting overhead aside, dm-writeboost is always the best of
all because it caches data in sequential manner - the most efficient I/O pattern
yet for the SSD caching device in terms of performance.

It's known from experiments that dm-writeboost performs no good when you create
a dm-writeboost'd device in virtual environment like KVM. So, keep in mind to
use this driver in a physical machine.


How To Use dm-writeboost
========================
Trigger caching device reformat
-------------------------------
The caching device is triggered reformating only if the first one sector of the
caching device is zeroed out. Note that this operation should be omitted when
you resume the caching device.
e.g. dd if=/dev/zero of=$CACHE oflag=direct bs=512 count=1

Construct dm-writeboost'd device
--------------------------------
You can construct dm-writeboost'd device with dmsetup create command.

<essential args>
<#optional args> <optional args>

- <#optional args> is twice the length of the following list.
- <optional args> is unordered list of key-value pairs.

<essential args>
backing_dev        : A block device having original data (e.g. HDD)
cache_dev          : A block device having caches (e.g. SSD)

<optional args>
see `Optional args`

e.g.
BACKING=/dev/sdb # example
CACHE=/dev/sdc # example
sz=`blockdev --getsz ${BACKING}`
dmsetup create wbdev --table "0 $sz writeboost $BACKING $CACHE 2 writeback_threshold 70"

Shut down the system
--------------------
On shutting down the system, you don't need to do anything at all. The data
and metadata is safely saved on the caching device. But, if you want to do
deconstruct the device manually, use dmsetup remove.

Resume after system reboot
--------------------------
To resume your caching device of the on-disk state, run dmsetup create command
with the same parameter but DO NOT zero out the first sector of the caching device.
This replays the logs on the caching device to rebuild the internal data structures.

Remove caching device
---------------------
If you want to detach your caching device for some reasons (you don't like
dm-writeboost anymore or you try to upgrade the caching device to a newly
perchased device) the safest way to do this is clean the dirty data up from your
caching device first and then deconstrust the dm-writeboost'd device.
You can do this by first suspend/resuming the device to drop all transient data
from RAM buffer and then sending drop_caches message to drop dirty cache blocks
from the caching device.
e.g.
dmsetup suspend wbdev; dmsetup resume wbdev
dmsetup message wbdev 0 drop_caches
dmsetup remove wbdev

Optional args
-------------
writeback_threshold (%)
  accepts: 0..100
  default: 0 (writeback disabled)
Writeback can be suppressed when the load of backing device is higher than
$writeback_threshold.

nr_max_batched_writeback
  accepts: 1..32
  default: 32
As optimization, dm-writeboost writes back $nr_max_batched_writeback segments
simultaneously. The dirty caches in the segments are sorted in ascending order
of the destination address and then written back. Setting large value can boost
the writeback performance.

update_sb_record_interval (sec)
  accepts: 0..3600
  default: 0 (disabled)
Update the superblock every $update_sb_record_interval second. 0 means disabled.
Superblock memorizes the last segment ID that was written back.
By enabling this, dm-writeboost in resuming can skip segments that's already
written back and thus can shorten the resume time.

sync_data_interval (sec)
  accepts: 0..3600
  default: 0 (disabled)
Sync all the volatile data every $sync_data_interval second. 0 means disabled.

read_cache_threshold (int)
  accepts: 0..127
  default: 0 (read caching disabled)
More than $read_cache_threshold * 4KB consecutive reads won't be staged.

write_around_mode (bool)
  accepts: 0..1
  default: 0
By enabling this, dm-writeboost writes data directly to the backing device.

Messages
--------
You can change the behavior of dm-writeboost'd device by message.

(1) Optional args
The following optional args can be tuned online.
e.g. dmsetup message wbdev 0 writeback_threshold 70

- writeback_threshold
- nr_max_batched_writeback
- update_sb_record_interval
- sync_data_interval
- read_cache_threshold

(2) Others
drop_caches
  Wait for all dirty data on the caching device to be written back to the backing
  device. This is interruptible.
clear_stat
  Clear the statistic info (see `Status`).

Status
------
<cursor_pos>
<nr_cache_blocks>
<nr_segments>
<current_id>
<last_flushed_id>
<last_writeback_id>
<nr_dirty_cache_blocks>
<stat (write?) x (hit?) x (on buffer?) x (fullsize?)>
<nr_partial_flushed>
<#optional args> <optional args>
