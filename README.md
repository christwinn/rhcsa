# rhcsa
learnrhcsa.com scripts modified for KVM guest and RedHat 10.2

The site appears to have been written for RH9 but 10 has changes :-) 

The scripts to break the system are oops broken in RedHat 10

As I fix them I want to be able to pull them into my base machine so that is the whole point of this repo. 

Also the grading scripts rely on bare metal and/or virtual guests disks are different, i.e it looks for /dev/sdb while I have /dev/vdb
so scripts updated to reflect this. 

Scripts to be given back once all good.

# learnrhcsa vm
	base 10GB disk
	minimal install 10.2
	not connected to redhat
	root disabled
	no swap
	student learnrhcsa123! sudoer
## once installed 
	add /dev/vdb
	/etc/default/grub timeout=10
	grub2-mkconfig -o /boot/grub2/grub.cfg
	grubby --update-kernel=ALL --args="console=ttyS0"
	shutdown to test. initial start may not wait. 
	log in as student
	mkdir ~/exams; cd ~/exams

	run the script to gather the files, we will update these as we work through. 
	No! it is not cheating if the scripts do not 
	1 work 
	or 
	2 validate correctly, things have changed 
	
``` bash
	BASE="https://raw.githubusercontent.com/christwinn/rhcsa/refs/heads/main/scripts"; \
	for i in {1..5}; \
	do curl $BASE/break_exam${i}.sh -o break_exam${i}.sh; \
	curl $BASE/grade_exam${i}.sh -o grade_exam${i}.sh; \
	done
```
	
	SNAPSHOT!

	go to (learnrhcsa.com)[https://learnrhcsa.com] and begin the fun
