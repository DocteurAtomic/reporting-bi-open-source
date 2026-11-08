-- Compares the components of a page of SQLPage with the result of one reference query.
-- Appended by setup/verify-page.sh after it has loaded the JSON of the page into the temporary
-- table j (column doc: the array that SQLPage returns for Accept: application/json, one object
-- per component, then one object per row of that component) and created the temporary view
-- expected (one query of the references). Never run alone. Writes nothing: every object is
-- temporary and vanishes with the session.
-- Prints one line per component that has rows: its number, a rank and a verdict, separated by
-- "|". Rank 0: the component gives the rows of the reference. Rank 1: as many rows, other
-- values. Rank 2: as many rows, but no key of the rows holds numbers where the reference has
-- numbers (an amount formatted as text, for instance). Rank 3: another number of rows.
-- A column of the reference matches a key of the rows whatever their names: the key whose
-- values, sorted, are the values of the column. The rows are then compared whole, so that two
-- right columns put side by side on the wrong rows still fail. The order of the rows is ignored.

-- A value of each side, written the same way: numbers rounded to six decimals without trailing
-- zeros, dates and times as timestamps without time zone, booleans as true or false, the rest
-- as text. The kind follows the column of the reference query.
create function pg_temp.norm(v text, cat "char") returns text language plpgsql immutable as $$
begin
    if v is null then return null; end if;
    if cat = 'N' then return trim_scale(round(v::numeric, 6))::text; end if;
    if cat = 'D' then return v::timestamp::text; end if;
    if cat = 'B' then return v::boolean::text; end if;
    return v;
exception when others then
    return 'not a ' || case cat when 'N' then 'number' when 'D' then 'date' else 'boolean' end || ': ' || v;
end $$;

create temp table want_cols as
select a.attnum::int as i, a.attname::text as name, t.typcategory as cat
  from pg_attribute a join pg_type t on t.oid = a.atttypid
 where a.attrelid = 'pg_temp.expected'::regclass and a.attnum > 0 and not a.attisdropped;

create temp table want_cells as
select r.n::int, x.i::int, pg_temp.norm(x.v, w.cat) as v
  from (select row_number() over () as n, row_to_json(e) as js from expected e) r
 cross join lateral json_each_text(r.js) with ordinality x(k, v, i)
  join want_cols w on w.i = x.i;

create temp table want_rows as
select n, array_agg(v order by i) as vals from want_cells group by n;

-- The page: each object that has a key "component" starts a component; the objects that follow
-- are its rows.
create temp table elems as
select x.n::int, x.e from j, jsonb_array_elements(j.doc) with ordinality x(e, n);
create temp table comps as
select n as start, row_number() over (order by n)::int as k, e->>'component' as name
  from elems where e ? 'component';
create temp table page_rows as
select c.k, el.n as r
  from elems el
  join lateral (select k from comps where comps.start < el.n order by comps.start desc limit 1) c on true
 where not el.e ? 'component';
create temp table page_cells as
select pr.k, pr.r, x.key, x.value
  from page_rows pr join elems el on el.n = pr.r, jsonb_each_text(el.e) x(key, value);

create function pg_temp.match(comp int) returns text language plpgsql as $$
declare
    nwant int; ngot int; col record; found text; want_vals text; kind_ok boolean;
    used text[] := '{}'; cats "char"[] := '{}'; ndiff int;
begin
    select count(*) into nwant from want_rows;
    select count(*) into ngot from page_rows where k = comp;
    if ngot <> nwant then
        return '3|FAIL rows: ' || ngot || ' rows in the component, ' || nwant || ' in the reference';
    end if;
    for col in select i, name, cat from want_cols order by i loop
        select string_agg(coalesce(v, '(empty)'), ' | ' order by coalesce(v, '(empty)'))
          into want_vals from want_cells where i = col.i;
        select g.key into found
          from (select pc.key,
                       string_agg(coalesce(pg_temp.norm(pc.value, col.cat), '(empty)'), ' | '
                                  order by coalesce(pg_temp.norm(pc.value, col.cat), '(empty)')) as s,
                       count(*) as cnt
                  from page_cells pc where pc.k = comp group by pc.key) g
         where g.cnt = ngot and g.s is not distinct from want_vals and g.key <> all(used)
         order by g.key limit 1;
        if found is null then
            select exists (select from (select pc.key, bool_and(coalesce(pg_temp.norm(pc.value, col.cat), '') not like 'not a %') as ok,
                                               count(*) as cnt
                                          from page_cells pc where pc.k = comp group by pc.key) g
                            where g.ok and g.cnt = ngot and g.key <> all(used))
              into kind_ok;
            if not kind_ok then
                return '2|FAIL columns: no key of the rows holds ' || case col.cat when 'N' then 'numbers' when 'D' then 'dates' else 'values of that kind' end
                       || ' for the column "' || col.name || '" of the reference (a number formatted as text?)';
            end if;
            return '1|FAIL rows: no key of the rows gives the values of the column "' || col.name
                   || '"; expected values: ' || left(want_vals, 120);
        end if;
        used := used || found;
        cats := cats || col.cat;
    end loop;
    with got as (
        select pr.r, array_agg(pg_temp.norm(pc.value, cats[u.ord]) order by u.ord) as vals
          from page_rows pr
         cross join unnest(used) with ordinality u(key, ord)
          left join page_cells pc on pc.k = pr.k and pc.r = pr.r and pc.key = u.key
         where pr.k = comp
         group by pr.r)
    select count(*) into ndiff
      from ((select vals from got except all select vals from want_rows)
            union all
            (select vals from want_rows except all select vals from got)) d;
    if ndiff <> 0 then
        return '1|FAIL rows: each column holds the right values, but ' || ndiff
               || ' rows pair them differently from the reference';
    end if;
    return '0|PASS: ' || ngot || ' rows, the same as the reference (keys ' || array_to_string(used, ', ') || ')';
end $$;

select c.k || '|' || pg_temp.match(c.k)
  from comps c
 where exists (select from page_rows pr where pr.k = c.k)
 order by c.k;
