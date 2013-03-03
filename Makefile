KERNEL_TREE := /lib/modules/$(shell uname -r)/build
#KERNEL_TREE := $(HOME)/linux-$(KERN_VERSION)

PWD := $(shell pwd)

EXTRA_CFLAGS += -O0 -DCONFIG_DM_DEBUG -fno-inline #-Wall

obj-m := dm-lc.o

all:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) clean
