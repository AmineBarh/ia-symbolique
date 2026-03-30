%%%  ============================================================
%%%  reif.pl — Reified Conditionals for SWI-Prolog
%%%  Subset of Ulrich Neumerkel's reif library:
%%%    http://www.complang.tuwien.ac.at/ulrich/Prolog-inedit/swi/reif.pl
%%%
%%%  Provides:
%%%    if_/3         — declarative if-then-else (no CWA, no cut-over-choice)
%%%    member_t/3    — reified list membership
%%%    =/3           — reified unification  (called as =(X,Y,T))
%%%    singleton_t/2 — reified singleton list check
%%%    true_t/1      — trivially true reified condition
%%%    false_t/1     — trivially false reified condition
%%%    and_t/3       — reified conjunction
%%%    or_t/3        — reified disjunction
%%%    not_t/2       — reified negation
%%%
%%%  Usage pattern:
%%%    if_(Cond_1, Then_0, Else_0)
%%%    where Cond_1 is Goal/1 — receives a boolean (true/false) as last arg
%%%
%%%  Example:
%%%    if_(member_t(X, List), write(found), write(not_found))
%%%  ============================================================

:- module(reif, [
    if_/3,
    member_t/3,
    '='/3,           %% reified unification — quoted because = is an operator
    singleton_t/2,
    true_t/1,
    false_t/1,
    and_t/3,
    or_t/3,
    not_t/2
]).

:- meta_predicate if_(1, 0, 0).
:- meta_predicate and_t(1, 1, ?).
:- meta_predicate or_t(1, 1, ?).
:- meta_predicate not_t(1, ?).

% ---------------------------------------------------------------------------
% if_(+Cond_1, +Then_0, +Else_0)
%
%   Declarative if-then-else.
%   Cond_1 is called with one extra boolean argument T.
%   If T = true  → Then_0 is called.
%   If T = false → Else_0 is called.
%
%   Key property: if Cond_1 is determinate and its boolean is ground,
%   exactly one branch is taken with no choice point left.
%   This is what makes if_/3 superior to (-> ; ) for CLP.
% ---------------------------------------------------------------------------
if_(Cond_1, Then_0, Else_0) :-
    call(Cond_1, T),
    (   T == true  -> call(Then_0)
    ;   T == false -> call(Else_0)
    ;   throw(error(type_error(boolean, T), context(if_/3, _)))
    ).

% ---------------------------------------------------------------------------
% =(+X, +Y, ?T)   — reified unification
%
%   T = true  if X and Y unify
%   T = false if X and Y do not unify (X \= Y, i.e., they are not unifiable)
%
%   For ground terms this is simply structural equality comparison.
% ---------------------------------------------------------------------------
'='(X, Y, T) :-
    (  X == Y  -> T = true
    ;  X \= Y  -> T = false
    ;  T = true,  X = Y         %% unification succeeds, commit
    ;  T = false                %% represent non-unification
    ).

% ---------------------------------------------------------------------------
% member_t(+Elem, +List, ?T)
%
%   Reified list membership.
%   T = true  if Elem is a member of List
%   T = false if Elem is not a member of List
%
%   For ground Elem and List this is deterministic.
% ---------------------------------------------------------------------------
member_t(_Elem, [], false).
member_t(Elem, [H|T], Truth) :-
    (   Elem == H  -> Truth = true
    ;   Elem \= H  -> member_t(Elem, T, Truth)
    ;   ( Truth = true               %% Elem might unify with H
        ; member_t(Elem, T, Truth)   %% or a later element
        )
    ).

% ---------------------------------------------------------------------------
% singleton_t(+List, ?T)
%
%   T = true  if List has exactly one element
%   T = false otherwise
% ---------------------------------------------------------------------------
singleton_t([_],     true).
singleton_t([],      false).
singleton_t([_,_|_], false).

% ---------------------------------------------------------------------------
% true_t(?T)  — always true
% false_t(?T) — always false
% ---------------------------------------------------------------------------
true_t(true).
false_t(false).

% ---------------------------------------------------------------------------
% and_t(+A_1, +B_1, ?T)
%
%   Reified conjunction: T = true iff both A_1 and B_1 are true.
%   Short-circuits: if A is false, B is not called.
% ---------------------------------------------------------------------------
and_t(A_1, B_1, T) :-
    if_(A_1, if_(B_1, T = true, T = false), T = false).

% ---------------------------------------------------------------------------
% or_t(+A_1, +B_1, ?T)
%
%   Reified disjunction: T = true iff at least one of A_1, B_1 is true.
%   Short-circuits: if A is true, B is not called.
% ---------------------------------------------------------------------------
or_t(A_1, B_1, T) :-
    if_(A_1, T = true, if_(B_1, T = true, T = false)).

% ---------------------------------------------------------------------------
% not_t(+A_1, ?T)
%
%   Reified negation: T = true iff A_1 is false.
% ---------------------------------------------------------------------------
not_t(A_1, T) :-
    if_(A_1, T = false, T = true).
