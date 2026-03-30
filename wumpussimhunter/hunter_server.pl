#!/usr/bin/env swipl

:- use_module(library(main)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_client)).
:- use_module(library(settings)).

:- set_setting(http:cors, [*]).

:- use_module(hunter).

:- initialization(run, main).

run :-
    http_server(http_dispatch, [port(8081)]),
    format('Hunter Server is running on port 8081. Press Ctrl+C to stop.~n'),
    thread_get_message(_).

:- http_handler(root(action), handle_action, []).

handle_action(Request) :-
    memberchk(method(options), Request), !,
    cors_enable(Request, [methods([put, options])]),
    format('Content-type: text/plain\r\n\r\n').

handle_action(Request) :-
    cors_enable,
    http_read_json_dict(Request, StateIn, [value_string_as(atom), tag('')]),
    catch(
        handle_action_inner(StateIn),
        Error,
        (
            print_message(error, Error),
            format(user_error, '~n=== HUNTER SERVER ERROR ===~n~w~n================~n~n', [Error]),
            reply_json_dict(_{error: "internal_error", hunterState: StateIn, action: move})
        )
    ).

handle_action_inner(HunterStateJSON) :-
    Step = HunterStateJSON.beliefs.step,
    format(user_error, '[hunter] Processing Step ~w...~n', [Step]),
    
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

merge_sim_knowledge(HState, World, NewHState) :-
    Beliefs = HState.beliefs,
    SimEternals = World.eternals,
    
    NewCertainEternals = Beliefs.certain_eternals
        .put(eat_exit, SimEternals.eat_exit)
        .put(eat_walls, SimEternals.eat_walls)
        .put(cells, SimEternals.cells),
    
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

