#!/bin/sh

test_description='pull signature verification tests'
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPG 'create repositories with signed commits' '
	echo 1 >a && git add a &&
	test_tick && git commit -m initial &&
	git tag initial &&

	git clone . signed &&
	(
		cd signed &&
		echo 2 >b && git add b &&
		test_tick && git commit -S -m "signed"
	) &&

	git clone . unsigned &&
	(
		cd unsigned &&
		echo 3 >c && git add c &&
		test_tick && git commit -m "unsigned"
	) &&

	git clone . bad &&
	(
		cd bad &&
		echo 4 >d && git add d &&
		test_tick && git commit -S -m "bad" &&
		git cat-file commit HEAD >raw &&
		sed -e "s/^bad/forged bad/" raw >forged &&
		git hash-object -w -t commit forged >forged.commit &&
		git checkout $(cat forged.commit)
	) &&

	git clone . untrusted &&
	(
		cd untrusted &&
		echo 5 >e && git add e &&
		test_tick && git commit -SB7227189 -m "untrusted"
	)
'

test_expect_success GPG 'pull unsigned commit with --verify-signatures' '
	test_when_finished "git reset --hard && git checkout initial" &&
	test_must_fail git pull --ff-only --verify-signatures unsigned 2>pullerror &&
	test_i18ngrep "does not have a GPG signature" pullerror
'

test_expect_success GPG 'pull commit with bad signature with --verify-signatures' '
	test_when_finished "git reset --hard && git checkout initial" &&
	test_must_fail git pull --ff-only --verify-signatures bad 2>pullerror &&
	test_i18ngrep "has a bad GPG signature" pullerror
'

test_expect_success GPG 'pull commit with untrusted signature with --verify-signatures' '
	test_when_finished "git reset --hard && git checkout initial" &&
	test_must_fail git pull --ff-only --verify-signatures untrusted 2>pullerror &&
	test_i18ngrep "has an untrusted GPG signature" pullerror
'

test_expect_success GPG 'pull signed commit with --verify-signatures' '
	test_when_finished "git reset --hard && git checkout initial" &&
	git pull --verify-signatures signed >pulloutput &&
	test_i18ngrep "has a good GPG signature" pulloutput
'

test_expect_success GPG 'pull commit with bad signature without verification' '
	test_when_finished "git reset --hard && git checkout initial" &&
	git pull --ff-only bad 2>pullerror
'

test_expect_success GPG 'pull commit with bad signature with --no-verify-signatures' '
	test_when_finished "git reset --hard && git checkout initial" &&
	test_config merge.verifySignatures true &&
	test_config pull.verifySignatures true &&
	git pull --ff-only --no-verify-signatures bad 2>pullerror
'

test_done
