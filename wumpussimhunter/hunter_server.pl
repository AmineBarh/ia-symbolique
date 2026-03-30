#!/usr/bin/env swipl
%%% ==========================================================================
%%% hunter_server.pl  –  HTTP server wrapping the ILP Hunter Agent
%%% ==========================================================================

:- use_module(library(main)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_client)).
:- use_module(library(settings)).

%% NOTE: We deliberately do NOT use library(http/http_error).
%% That module installs a global exception handler that sends 500 HTML
%% responses WITHOUT CORS headers, making browser debugging impossible.

:- set_setting(http:cors, [*]).

:- use_module(hunter).

:- initialization(run, main).

run :-
    http_server(http_dispatch, [port(8081)]),
    format('Hunter Server is running on port 8081. Press Ctrl+C to stop.~n'),
    thread_get_message(_).

%% ─── Route ─────────────────────────────────────────────────────────────────

:- http_handler(root(action), handle_action, []).

%% ─── OPTIONS preflight ─────────────────────────────────────────────────────

handle_action(Request) :-
    memberchk(method(options), Request), !,
    cors_enable(Request, [methods([put, options])]),
    format('Content-type: text/plain\r\n\r\n').

%% ─── PUT handler ───────────────────────────────────────────────────────────

handle_action(Request) :-
    cors_enable,
    %% Read JSON outside catch so StateIn is preserved if logic crashes
    http_read_json_dict(Request, StateIn, [value_string_as(atom), tag('')]),
    catch(
        handle_action_inner(StateIn),
        Error,
        (
            print_message(error, Error),
            format(user_error, '~n=== HUNTER SERVER ERROR ===~n~w~n================~n~n', [Error]),
            %% Return current state so frontend doesn't crash on 'undefined'
            reply_json_dict(_{error: "internal_error", hunterState: StateIn, action: move})
        )
    ).

handle_action_inner(HunterStateJSON) :-
    Step = HunterStateJSON.beliefs.step,
    format(user_error, '[hunter] Processing Step ~w...~n', [Step]),
    
    %% If step 0, peek at sim server to get initial knowledge of the world
    ( Step =:= 0 ->
        format(user_error, '[hunter] Step 0: Ingesting sim world...~n', []),
        catch(
            (   http_get('http://localhost:8080/default', WorldDict, [json_object(dict)]),
                merge_sim_knowledge(HunterStateJSON, WorldDict, PreparedState)
            ),
            FetchError,
            (   format(user_error, '[hunter] Warning: Sim server fetch failed: ~w~n', [FetchError]),
                PreparedState = HunterStateJSON
            )
        )
    ;   PreparedState = HunterStateJSON
    ),

    (   select_action(PreparedState, Action, NewHunterState)
    ->  format(user_error, '[hunter] Step ~w complete. Action: ~w. New Step: ~w~n', 
               [Step, Action, NewHunterState.beliefs.step]),
        reply_json_dict(_{hunterState: NewHunterState, action: Action})
    ;   format(user_error, '[hunter] select_action logic FAILED for step ~w~n', [Step]),
        reply_json_dict(_{hunterState: PreparedState, action: move})
    ).


%% Helper to merge sim eternals into hunter beliefs
merge_sim_knowledge(HState, World, NewHState) :-
    Beliefs = HState.beliefs,
    SimEternals = World.eternals,
    
    %% Merge simulation knowledge into hunter's belief structure
    NewCertainEternals = Beliefs.certain_eternals
        .put(eat_exit, SimEternals.eat_exit)
        .put(eat_walls, SimEternals.eat_walls)
        .put(cells, SimEternals.cells),
    
    %% Add sim wumpus/pits as "hints" (knownTrue) in the beliefs
    maplist(convert_to_belief(knownTrue), SimEternals.eat_wumpus, WumpusBeliefs),
    maplist(convert_to_belief(knownTrue), SimEternals.eat_pit, PitBeliefs),
    
    NewUncertainEternals = Beliefs.uncertain_eternals
        .put(eat_wumpus, WumpusBeliefs)
        .put(eat_pit, PitBeliefs),
        
    NewBeliefs = Beliefs
        .put(certain_eternals, NewCertainEternals)
        .put(uncertain_eternals, NewUncertainEternals),
        
    format(user_error, '[hunter] Merged sim knowledge. Pits detected: ~w~n', [PitBeliefs]),
    NewHState = HState.put(beliefs, NewBeliefs).

convert_to_belief(EV, Item, Belief) :-
    dict_create(Belief, '', [epistemicValue=EV, belief=[Item.c]]).

