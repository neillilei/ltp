/*
 * st_rtc_parser.c
 *
 * This file contains i2c parser and gives user selectable test cases
 *
 * Copyright (C) 2010 Texas Instruments Incorporated - http://www.ti.com/ 
 * 
 * 
 *  Redistribution and use in source and binary forms, with or without 
 *  modification, are permitted provided that the following conditions 
 *  are met:
 *
 *    Redistributions of source code must retain the above copyright 
 *    notice, this list of conditions and the following disclaimer.
 *
 *    Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the 
 *    documentation and/or other materials provided with the   
 *    distribution.
 *
 *    Neither the name of Texas Instruments Incorporated nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
*/

/*Testcode related header files */
#include "st_rtc_common.h"
#include "st_rtc_parser.h"

char testcaseid[ST_TESTCASEID_LEN] = "rtc_tests";

/* Test case options structure */
extern struct st_rtc_testparams testoptions;

/*Function to display test suite version */
static void st_display_rtc_testsuite_version();

/* Function to get the hex value from the str */
unsigned long st_get_unsigned(const char *str);

/* Macro Definations */
#define DEFAULT_LOOP_COUNT	1
#define DEFAULT_READONLY	0

/****************************************************************************
 * Function		- st_process_rtc_test_options 
 * Functionality	- This function parses the command line options and 
			- values passed for the options
 * Input Params		-  argc,argv
 * Return Value		-  None
 * Note			-  None
 ****************************************************************************/
static int st_process_rtc_test_options(int argc, char **argv)
{
	int error = TRUE;
	int version = FALSE;
	int help = FALSE;
	int ret_val = SUCCESS;
	int result = SUCCESS;
	int loop_count = 0;
	int i = 0;
	char ioctl_name[ST_IOCTL_NAME_LEN];
	for (;;) {
		int option_index = 0;

    /** Options for getopt - New test case options added need to be
         * populated here*/
		static struct option long_options[] = {
			{"device", required_argument, NULL, OPTION_DEVICE_NAME},
			{"ioctltest", optional_argument, NULL, OPTION_IOCTL},
			{"ioctltestarg", optional_argument, NULL,
			 OPTION_IOCTL_ARG},
			{"loop", optional_argument, NULL, OPTION_LOOP},
			{"id", optional_argument, NULL, OPTION_TESTCASE_ID},
			{"readonly", optional_argument, NULL, OPTION_READONLY},
			{"version", no_argument, NULL, OPTION_VERSION},
			{"help", no_argument, NULL, OPTION_HELP},
			{NULL, 0, NULL, 0}
		};
		int c = getopt_long_only(argc, argv, "vh", long_options,
					 &option_index);
		if (c == -1) {
			break;
		}
		if (c == '?') {
			error = TRUE;
			break;
		}
		switch (c) {
		case OPTION_DEVICE_NAME:
			error = FALSE;
			if (optarg != NULL) {
				strcpy(testoptions.device, optarg);
			}
			break;
		case OPTION_TESTCASE_ID:
			if (optarg != NULL) {
				strcpy(testcaseid, optarg);
			} else if (optind < argc && ('-' != argv[optind][0])) {
				strcpy(testcaseid, argv[optind]);
			}
			break;
		case OPTION_READONLY:
			testoptions.readonly=1;
			break;
		case OPTION_IOCTL:
			if (optarg != NULL) {
				strcpy(ioctl_name, optarg);
			} else if ((optind < argc && ('-' != argv[optind][0]))) {
				strcpy(ioctl_name, argv[optind]);
			} else {
				strcpy(ioctl_name, DEFAULT_IOCTLTEST_NAME);
			}
			while ((strcmp
				((ioctl_table[i].ioctl_testcasename),
				 ioctl_name)
				!= 0)
			       &&
			       (strcmp
				(ioctl_table[i].ioctl_testcasename,
				 "NULL") != 0)) {
				i++;
			}
			if (0 ==
			    strcmp(ioctl_table[i].ioctl_testcasename, "NULL")) {
				error = TRUE;
			} else {
				testoptions.ioctl_testcase =
				    ioctl_table[i].ioctl_testcase;
				testoptions.ioctl_testcasearg =
				    ioctl_table[i].ioctl_testcasearg;
			}
			break;

		case OPTION_LOOP:
			if (optarg != NULL) {
				testoptions.loop = atoi(optarg);
			} else if (optind < argc && ('-' != argv[optind][0])) {
				testoptions.loop = atoi(argv[optind]);
			}

			break;
		case OPTION_IOCTL_ARG:
			if (optarg != NULL) {
				testoptions.ioctl_testcasearg = atoi(optarg);
			} else if (optind < argc && ('-' != argv[optind][0])) {
				testoptions.ioctl_testcasearg =
				    atoi(argv[optind]);
			}

			break;
		case OPTION_VERSION:
			version = TRUE;
			st_display_rtc_testsuite_version();
			break;
		case OPTION_HELP:
			help = TRUE;
			break;
		}
	}
	if (error == TRUE || help == TRUE) {
		if (version)
			exit(0);
		else
			st_display_rtc_test_suite_help();
		if( error == TRUE)
			result = FAILURE;
	} else {
		TEST_PRINT_TST_START(testcaseid);
		st_print_rtc_test_params(&testoptions, testcaseid);
		while (testoptions.loop > loop_count) {
			ret_val = st_rtc_ioctl_test(&testoptions, testcaseid);
			if (SUCCESS != ret_val) {
				result = FAILURE;
				break;
			}
			loop_count++;
		}
		TEST_PRINT_TST_RESULT(result, testcaseid);
		TEST_PRINT_TST_END(testcaseid);
	}
	return result;
}

/****************************************************************************
 * Function                 - st_display_rtc_testsuite_version
 * Functionality        - This function displays the test suite version
 * Input Params             - None 
 * Return Value             - None
 * Note                         - None
 ****************************************************************************/
static void st_display_rtc_testsuite_version()
{
	TEST_PRINT_TRC("Version : %s", VERSION_STRING);
}

/****************************************************************************
 * Function                 - Main function
 * Functionality        - This is where the execution begins
 * Input Params         - argc,argv
 * Return Value             - None
 * Note                         - None
 ****************************************************************************/
int main(int argc, char *argv[])
{

	int retval;
	/* Initialize options with default vales */
	st_init_rtc_test_params();

	/* Invoke the parser function to process the command line options */
	retval = st_process_rtc_test_options(argc, argv);
	return retval;
}
