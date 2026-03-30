%%% ==========================================================================
%%% run_aleph.pl  –  ALEPH Execution Script
%%% IAS 4A – ESIEA  |  HW2-ILP
%%%
%%% This file orchestrates the full ALEPH ILP learning run.
%%%
%%% Usage:
%%%   swipl -g "consult('run_aleph.pl'), halt" run_aleph.pl
%%% or interactively:
%%%   swipl run_aleph.pl
%%%   ?- induce.
%%%
%%% ALEPH must be available as aleph.pl in the same directory or loadable path.
%%% Download from: https://www.cs.ox.ac.uk/activities/programinduction/Aleph/aleph.html
%%% ==========================================================================

%% Load ALEPH (adjust path as needed)
:- [aleph].

%% Load background knowledge (mode declarations, determinations, BK predicates)
:- read_all('aleph_data/background').

%% Load positive examples
:- read_all('aleph_data/positive_examples').

%% Load negative examples  
:- read_all('aleph_data/negative_examples').

%% Run induction and save theory
:- induce,
   save('aleph_data/induced_theory').

%% Show confusion matrix
:- test(train, [confusion_matrix(true)]).
