---
name: grill-me
description: "Interview the user relentlessly until both sides hold one picture of the work, before any of it starts. It writes no spec. Use for /grill-me, \"grill me\", \"interview me first\", or new work whose shape the user has not settled."
disable-model-invocation: true
---

# Grill me

This interview settles what the user wants, and the angle to take, before any work starts. It writes no spec, no plan, and no file.

## 1. Look before you ask

Read what the user pointed at and the code that it touches. A fact is yours to find, and a decision is the user's to make. Never ask what the repo, the docs, or a command can answer. When a fact takes long to find, send an `Explore` agent for it and go on with the questions that do not wait on it.

## 2. Ask in rounds

- A round holds every question that you can ask now without guessing an answer you have not heard.
- Number the questions. Give each one the answer you recommend, and the reason in one line.
- Word each question so that a plain "yes" takes your recommendation.
- A question that hangs on an open one waits for a later round.
- Ask only what changes what gets built, or how. State every other choice as your call in one line, so the user can reject it.

## 3. Push back

The baseline is a compromise, not a record of what the user said. When an answer conflicts with the code, an earlier answer, or a cheaper way to the same goal, say so and name the trade. Follow a vague answer with a sharper question. Take "you decide" as leave to decide, and say what you chose.

## 4. Stop when nothing is open

The interview ends when no decision is open and nothing is assumed in silence. Reply with the baseline, as short as the settled decisions allow:

- the goal, and how both sides will know that it is met
- the decisions that the interview settled
- what is out of scope
- the angle of attack, and the first step

Ask the user to confirm it or correct it, and start no work before that. From then on the baseline opens every kickoff.
