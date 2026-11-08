-- Compares the result of a Metabase question with the result of the reference query.
-- Appended by setup/check.sh after it has loaded the answer of Metabase into the temporary
-- table j (column doc, the JSON of POST /api/card/<id>/query), created the temporary view
-- expected (exercises/module_NN/reference.sql) and set the psql variable ordered (true when
-- the exercise checks the order of the rows). Never run alone. Writes nothing: every object
-- is temporary and vanishes with the session.
-- The last line printed is the verdict that check.sh turns into its exit code.

-- A value of each side, written the same way: numbers rounded to six decimals without
-- trailing zeros (Metabase returns floating-point numbers, PostgreSQL exact ones), dates and
-- times as timestamps without time zone (Metabase writes 2011-01-01T00:00:00Z), the rest as
-- text. The kind follows the column of the reference query.
create function pg_temp.norm(v text, cat "char") returns text language plpgsql immutable as $$
begin
    if v is null then return null; end if;
    if cat = 'N' then return trim_scale(round(v::numeric, 6))::text; end if;
    if cat = 'D' then return v::timestamp::text; end if;
    return v;
exception when others then
    return 'not a ' || case cat when 'N' then 'number' else 'date' end || ': ' || v;
end $$;

create temp table want_cols as
select a.attnum::int as i, a.attname::text as name, t.typcategory as cat
  from pg_attribute a join pg_type t on t.oid = a.atttypid
 where a.attrelid = 'pg_temp.expected'::regclass and a.attnum > 0 and not a.attisdropped;

create temp table got_cols as
select c.i::int, c.col->>'display_name' as name, c.col->>'base_type' as base_type
  from j, jsonb_array_elements(doc->'data'->'cols') with ordinality c(col, i);

-- The columns: as many as the reference, and numbers where the reference has numbers.
select (select count(*) from got_cols) as n_got_cols,
       (select count(*) from want_cols) as n_want_cols,
       (select string_agg(name, ', ' order by i) from got_cols) as got_names,
       (select string_agg(name, ', ' order by i) from want_cols) as want_names,
       (select count(*) from got_cols g join want_cols w using (i)
         where (w.cat = 'N') <> (g.base_type in ('type/Integer', 'type/BigInteger', 'type/Float',
                                                'type/Decimal', 'type/Number', 'type/Currency'))) as n_kind_diff \gset
select :n_got_cols = :n_want_cols as same_cols \gset
\if :same_cols
\else
\echo 'FAIL columns: different columns,' :n_got_cols 'columns (' :got_names ') instead of' :n_want_cols '(' :want_names ')'
\q
\endif
select :n_kind_diff = 0 as same_kinds \gset
\if :same_kinds
\else
\echo 'FAIL columns: a column holds text where the reference holds numbers, or the reverse; got' :got_names 'for' :want_names
\q
\endif

create temp table got as
select r.n::int, array_agg(pg_temp.norm(x.v, w.cat) order by x.i) as vals
  from j, jsonb_array_elements(doc->'data'->'rows') with ordinality r(rw, n)
 cross join lateral jsonb_array_elements_text(r.rw) with ordinality x(v, i)
  join want_cols w on w.i = x.i
 group by r.n;

create temp table want as
select r.n::int, array_agg(pg_temp.norm(x.v, w.cat) order by x.i) as vals
  from (select row_number() over () as n, row_to_json(e) as js from expected e) r
 cross join lateral json_each_text(r.js) with ordinality x(k, v, i)
  join want_cols w on w.i = x.i
 group by r.n;

\if :ordered
create temp view extra as select n, vals from got except all select n, vals from want;
create temp view missing as select n, vals from want except all select n, vals from got;
\else
create temp view extra as select vals from got except all select vals from want;
create temp view missing as select vals from want except all select vals from got;
\endif

select (select count(*) from extra) + (select count(*) from missing) as diff,
       (select count(*) from got) as n_got,
       (select count(*) from want) as n_want \gset
select :diff = 0 as same_rows \gset
\if :same_rows
\echo 'PASS:' :n_got 'rows, the same as the reference'
\else
select 'not expected: ' || array_to_string(vals, ' | ', '(empty)') from (select vals from extra limit 5) e;
select 'missing:      ' || array_to_string(vals, ' | ', '(empty)') from (select vals from missing limit 5) m;
\if :ordered
\echo 'FAIL rows: different rows or a different order,' :n_got 'rows instead of' :n_want
\else
\echo 'FAIL rows: different rows,' :n_got 'rows instead of' :n_want
\endif
\endif
