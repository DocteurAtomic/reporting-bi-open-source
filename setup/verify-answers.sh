#!/usr/bin/env bash
# Verifies a file of answers written by hand after asking questions to an AI (module 9: the
# answers of Metabot), against reference queries run in psql.
# Usage: ./setup/verify-answers.sh REFERENCE.sql
# - The line "-- check: answers work/answer09.csv" in the first five lines of REFERENCE.sql
#   names the file, relative to the root of the clone.
# - The file has one line per question, fields separated by semicolons:
#       question;chiffre;verdict;lecture
#   question is the id of the question (E01), chiffre the number the AI answered, written in
#   full (22486000, 22 486 000 or 3451,95; spaces, %, € and a decimal comma are accepted),
#   verdict "juste" or "faux" (right or wrong, as you judged it after checking), and lecture
#   the reading the AI chose, in your words (free text, not checked). A first line that starts
#   with "question" is a header; empty lines and lines that start with # are skipped.
# - REFERENCE.sql is a query that gives one row per accepted reading of a question:
#   (question, lecture, valeur). Every question of the reference must have exactly one line in
#   the file, and no other question. A line marked "juste" must equal one of the values of its
#   question, rounded to the decimals written (7,5 matches 7.45, 3452 matches 3451.95); a line
#   marked "faux" must equal none of them: the check does not grade the AI, it checks that your
#   verdicts agree with the reference. The values of the reference are never printed.
# The file and the query are read by PostgreSQL in the db container: bash, nothing else.
# Exit codes, as check.sh: 0 every line agrees with the reference; 1 the lab or the arguments;
# 2 the file is missing or empty; 3 a question is missing, repeated or unknown, or a verdict
# disagrees with the reference; 4 a line does not have its fields, a number is not a number,
# or a verdict is neither juste nor faux.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

ref=${1:-}
[ -f "$ref" ] || { echo "usage: $0 REFERENCE.sql (with a line \"-- check: answers FILE\")" >&2; exit 1; }
file=$(head -5 "$ref" | sed -n 's/^-- check: answers  *//p' | tr -d '\r' | head -1)
[ -n "$file" ] || { echo "No line \"-- check: answers FILE\" in the first lines of $ref" >&2; exit 1; }
lab_running "$c" || { echo "FAIL lab: the container $c (PostgreSQL) is not running; start the lab with ./setup/install.sh"; exit 1; }

if [ ! -s "$file" ]; then
    echo "FAIL missing: no file $file, or it is empty (write it as the exercise asks)"
    exit 2
fi
echo "Answers: $file"

result=$({
    echo '\set ON_ERROR_STOP on'
    echo 'create temp table raw (n serial, line text);'
    echo 'copy raw (line) from stdin;'
    # One line of the file per row of COPY text: tabs become spaces, backslashes are doubled,
    # carriage returns of a file saved on Windows are dropped.
    tr '\t' ' ' < "$file" | tr -d '\r' | sed 's/\\/\\\\/g'
    printf '\n\\.\n'
    printf 'create temp view expected as\n%s\n;\n' "$(sed 's/;[[:space:]]*$//' "$ref" | tr -d '\r')"
    cat <<'SQL'
create temp table answer as
select n, f,
       upper(trim(f[1])) as question,
       trim(coalesce(f[2], '')) as chiffre,
       lower(trim(coalesce(f[3], ''))) as verdict,
       regexp_replace(trim(coalesce(f[2], '')), '[[:space:]\u00a0\u202f€%]', '', 'g') as digits
  from raw, lateral (select string_to_array(line, ';') as f) x
 where trim(line) <> '' and trim(line) !~ '^#' and lower(trim(line)) !~ '^question';
alter table answer add column x numeric, add column decimals int;
update answer set digits = replace(digits, ',', '.');
update answer set x = digits::numeric, decimals = coalesce(length(substring(digits from '\.([0-9]+)$')), 0)
 where digits ~ '^-?[0-9]+(\.[0-9]+)?$';
with problems as (
    -- 4: a line without its fields, a number that is not one, a verdict that is neither.
    select 1 as kind, n, format('FAIL columns: line %s has %s field(s), at least 3 expected: question;chiffre;verdict;lecture',
                                n, coalesce(array_length(f, 1), 0)) as msg
      from answer where coalesce(array_length(f, 1), 0) < 3
    union all
    select 1, n, format('FAIL columns: %s, "%s" is not a number (write it in full, such as 22486000 or 3451,95)', question, chiffre)
      from answer where coalesce(array_length(f, 1), 0) >= 3 and x is null
    union all
    select 1, n, format('FAIL columns: %s, the verdict is "%s"; write juste or faux', question, verdict)
      from answer where coalesce(array_length(f, 1), 0) >= 3 and verdict not in ('juste', 'faux')
    union all
    -- 3: the questions of the file against those of the reference, then the verdicts.
    select 2, min(n), format('FAIL rows: %s is answered %s times, once expected', question, count(*))
      from answer group by question having count(*) > 1
    union all
    select 2, 0, format('FAIL rows: no line for %s', q.question)
      from (select distinct question from expected) q
     where not exists (select from answer a where a.question = q.question)
    union all
    select 2, n, format('FAIL rows: %s is not a question of the exercise', question)
      from answer a where coalesce(array_length(f, 1), 0) >= 3
                      and not exists (select from expected e where e.question = a.question)
    union all
    select 3, a.n, case when a.verdict = 'juste'
        then format('FAIL rows: %s is marked juste with %s, which matches none of the readings of the reference: check it in psql', a.question, a.chiffre)
        else format('FAIL rows: %s is marked faux with %s, which matches one of the readings of the reference: the answer was right', a.question, a.chiffre) end
      from answer a
     where a.x is not null and a.verdict in ('juste', 'faux')
       and exists (select from expected e where e.question = a.question)
       and (a.verdict = 'juste') <> exists (select from expected e
                                             where e.question = a.question and round(e.valeur, a.decimals) = a.x)
)
select msg from (
select kind, n, msg from problems
union all
select 9, 0, case
    when exists (select from problems where kind = 1) then 'FAIL columns: the file does not have the form asked for (see above)'
    when exists (select from problems) then 'FAIL rows: some lines disagree with the reference (see above)'
    else format('PASS: %s answers, %s marked juste and %s marked faux, each verdict agrees with the reference',
                (select count(*) from answer), (select count(*) from answer where verdict = 'juste'),
                (select count(*) from answer where verdict = 'faux')) end
) m order by kind, n;
SQL
} | psql_lab -d pachadataformation -q -At 2>&1)
code=$?
printf '%s\n' "$result"
[ "$code" = 0 ] || { echo "The check could not read the file or run the reference (psql exit $code)." >&2; exit 1; }
case "$(printf '%s\n' "$result" | tail -1)" in
    PASS*) exit 0 ;;
    'FAIL columns'*) exit 4 ;;
    'FAIL rows'*) exit 3 ;;
    *) exit 1 ;;
esac
