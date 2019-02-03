# this is all taken from https://github.com/stedolan/jq/issues/1475
# Emit a stream of the distinct items in the stream
# (avoid tojson)
def distinct(stream):
   reduce stream as $s ({};
     ($s|type) as $t
     | (if $t == "string" then $s else ($s|tostring) end) as $y
     | .[$t][$y] = [$s] )
   | .[][];

# Left Join
# left_joins/6 provides similar functionality to the SQL LEFT JOIN statement:
#   SELECT (Table1|p1), (Table2|p2)
#     FROM Table1
#     LEFT JOIN Table2 ON (Table1|filter1) = (Table2|filter2)
# where filter1, filter2, p1 and p2 are jq filters.

# left_joins(s1; s2; filter1; filter2; p1; p2)
# s1 and s2 are streams of objects corresponding to rows in Table1 and Table2;
# filter1 and filter2 determine the join criteria;
# p1 and p2 are projections determining the final results.
# Input: ignored
# Output: a stream of distinct pairs [p1, p2]
# Note: items in s1 for which filter1 == null are ignored,
# otherwise all rows are considered.

def left_joins(s1; s2; filter1; filter2; p1; p2):
  def it: type[0:1] + tostring;
  def ix(s;f):
    reduce s as $x ({};  ($x|f) as $y | if $y == null then . else .[$y|it] += [$x] end);
  # combine two dictionaries using the cartesian product of distinct elements
  def merge:
    .[0] as $d1 | .[1] as $d2
    | ($d1|keys_unsorted[]) as $k
    | distinct($d1[$k][]|p1) as $a
    | if $d2[$k] then distinct($d2[$k][]|p2) as $b | [$a,$b]
      else [$a, null]
      end ;

   [ix(s1; filter1), ix(s2; filter2)] | merge;

def left_joins(s1; s2; filter1; filter2):
  left_joins(s1; s2; filter1; filter2; .; .) | add ;

# Input: an array of two arrays of objects
# Output: a stream of the joined objects
def left_joins(filter1; filter2):
  left_joins(.[0][]; .[1][]; filter1; filter2);

# Input: an array of arrays of objects.
# Output: a stream of the joined objects where f defines the join criterion.
def left_joins(f):
  # j/0 is defined so TCO is applicable
  def j:
    if length < 2 then .[][]
    else [[ left_joins(.[0][]; .[1][]; f; f)]] + .[2:] | j
    end;
   j ;

#def distinct(s):
#  reduce s as $x ({}; .[$x | (type[0:1] + tostring)] = $x)
#  |.[];

# Relational Join
# joins/6 provides similar functionality to the SQL INNER JOIN statement:
#   SELECT (Table1|p1), (Table2|p2)
#     FROM Table1
#     INNER JOIN Table2 ON (Table1|filter1) = (Table2|filter2)
# where filter1, filter2, p1 and p2 are filters.

# joins(s1; s2; filter1; filter2; p1; p2)
# s1 and s2 are streams of objects corresponding to rows in Table1 and Table2;
# filter1 and filter2 determine the join criteria;
# p1 and p2 are filters determining the final results.
# Input: ignored
# Output: a stream of distinct pairs [p1, p2]
# Note: items in s1 for which filter1 == null are ignored, otherwise all rows are considered.
#
def joins(s1; s2; filter1; filter2; p1; p2):
  def it: type[0:1] + tostring;
  def ix(s;f):
    reduce s as $x ({};  ($x|f) as $y | if $y == null then . else .[$y|it] += [$x] end);
  # combine two dictionaries using the cartesian product of distinct elements
  def merge:
    .[0] as $d1 | .[1] as $d2
    | ($d1|keys_unsorted[]) as $k
    | if $d2[$k] then distinct($d1[$k][]|p1) as $a | distinct($d2[$k][]|p2) as $b | [$a,$b]
      else empty end;

   [ix(s1; filter1), ix(s2; filter2)] | merge;

def joins(s1; s2; filter1; filter2):
  joins(s1; s2; filter1; filter2; .; .) | add ;

# Input: an array of two arrays of objects
# Output: a stream of the joined objects
def joins(filter1; filter2):
  joins(.[0][]; .[1][]; filter1; filter2);

# Input: an array of arrays of objects.
# Output: a stream of the joined objects where f defines the join criterion.
def joins(f):
  # j/0 is defined so TCO is applicable
  def j:
    if length < 2 then .[][]
    else [[ joins(.[0][]; .[1][]; f; f)]] + .[2:] | j
    end;
   j ;
