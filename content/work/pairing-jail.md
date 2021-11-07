Title: Go directly to (pairing) jail
Date: 2021-11-06 19:00
Modified: 2021-11-07 23:15
Tags: pairing, xp
Authors: Jonathan Sharpe
Summary: Planning pair rotations to maximise context, diverse ideas, shared ownership, and team relationships.

In my [introduction to pairing] I wrote:

> Generally we rotate [pairs] on a daily basis, using tools like [Parrit] to make sure that every possible combination is occurring. If a story is still in flight from the previous day we _"stick and twist"_, with one person staying with the story to pass along the context and the other moving on to something else. This has the natural side effect that the more complex stories, the ones that take multiple days, get more people's input.

Context is certainly important here, we want to have a degree of consistency on a given track, so we minimise time spent re-learning information we already had within the team. However there are a few other things we're trying to maximise when choosing when and how to rotate the pairs in the team, including:

- **Diverse ideas** - different people's cultural and technical backgrounds mean they solve problems in different ways, the more different ideas we bring in the more likely it is we'll find the best one;
- **Shared ownership** - we want everyone to feel a collective responsibility for the whole codebase, so they're comfortable to refactor towards higher quality; and
- **Team relationships** - we want to give everyone in the team the chance to work with and get to know everyone else, especially if they're new.

You could maximise context retained by keeping one person working on the same track of work (this might be a single complex story, and epic comprising multiple stories, or work that's grouped due to e.g. domain) indefinitely, but that would risk missing these other objectives. Therefore we want to strike a balance between building up the context and actively sharing it around the team, which we can do through mindful pair rotations.

To support these rotations, some teams I've worked on have found it useful to maintain a _pairing table_, visualising how long people have remained on the same track. Each track has a row and there are columns for the number of consecutive days spent working on that track (usually up to five). The last space on each track is "jail" (and you don't want to end up in [jail], you don't pass Go or collect £200!)

In line with the Extreme Programming (XP) practice of the _Informative Workspace_, this would usually be posted up somewhere in the team's working area, e.g. a grid of painter's tape on a whiteboard with each developer on the team represented by an Instax photograph of them (these tend to be a bit more durable than just using stickies, and make it easier for visitors to identify the people they need to speak to about a given track). In these pandemic-influenced days you can achieve a similar effect in e.g. a Miro board (**pro-tip**: use the [table widget] to generate the structure easily):

![Illustration of a pairing table created in Miro][pairing table]

<small>Created in [Miro]. (Almost-)too-cute-to-eat dim sum by [Denise Yu], released under [CC BY-SA 4.0].</small>

<hr>

To see how this can be used in practice, let's run through a week on a 3-pair project. We'd wrapped up everything that had been in flight at the end of the last iteration, so everyone's starting on day 1 of their respective tracks:

<table style="table-layout: fixed; width: 100%">
    <thead>
        <tr><th>Track</th><th>🟢 Day 1</th><th>🟡 Day 2</th><th>🟠 Day 3</th><th>🔴 Day 4</th><th>🔥 Day 5</th></tr>
    </thead>
    <tbody>
        <tr><td><strong>Alpha</strong></td><td>Albert / Basti</td><td></td><td></td><td></td><td></td></tr>
        <tr><td><strong>Bravo</strong></td><td>Carol / Daniel</td><td></td><td></td><td></td><td></td></tr>
        <tr><td><strong>Charlie</strong></td><td>Ethel / Farah</td><td></td><td></td><td></td><td></td></tr>
    </tbody>
</table>

<hr>

When pairing up on Tuesday, we want to ensure that any context from Monday is kept in each track, so we _"stick"_ one person and _"twist"_ the other on each track:

<table style="table-layout: fixed; width: 100%">
    <thead>
        <tr><th>Track</th><th>🟢 Day 1</th><th>🟡 Day 2</th><th>🟠 Day 3</th><th>🔴 Day 4</th><th>🔥 Day 5</th></tr>
    </thead>
    <tbody>
        <tr><td><strong>Alpha</strong></td><td>Ethel</td><td>Albert</td><td></td><td></td><td></td></tr>
        <tr><td><strong>Bravo</strong></td><td>Basti</td><td>Daniel</td><td></td><td></td><td></td></tr>
        <tr><td><strong>Charlie</strong></td><td>Carol</td><td>Farah</td><td></td><td></td><td></td></tr>
    </tbody>
</table>

<hr>

On Wednesday, Ethel's out doing some training, so Albert continues on track Alpha to keep context there. We decide that Carol can solo on track Charlie, and rotate everyone else accordingly:

<table style="table-layout: fixed; width: 100%">
    <thead>
        <tr><th>Track</th><th>🟢 Day 1</th><th>🟡 Day 2</th><th>🟠 Day 3</th><th>🔴 Day 4</th><th>🔥 Day 5</th></tr>
    </thead>
    <tbody>
        <tr><td><strong>Alpha</strong></td><td>Daniel</td><td></td><td>Albert<td><td></td></tr>
        <tr><td><strong>Bravo</strong></td><td>Farah</td><td>Basti</td><td></td ><td></td><td></td></tr>
        <tr><td><strong>Charlie</strong></td><td></td><td>Carol</td><td></td><td></td><td></td></tr>
    </tbody>
</table>

<hr>

On Thursday, although Ethel's back, Daniel's sadly feeling under the weather.
That means Albert moves to day 4 of the track, so we definitely need to give
him a pair to let him rotate out before reaching day 5. We don't want to let
Carol continue soloing otherwise she'll end up on day 4 too, so Farah
solos on track Bravo.

<table style="table-layout: fixed; width: 100%">
    <thead>
        <tr><th>Track</th><th>🟢 Day 1</th><th>🟡 Day 2</th><th>🟠 Day 3</th><th>🔴 Day 4</th><th>🔥 Day 5</th></tr>
    </thead>
    <tbody>
        <tr><td><strong>Alpha</strong></td><td>Basti</td><td></td><td></td><td>Albert</td><td></td></tr>
        <tr><td><strong>Bravo</strong></td><td></td><td>Farah</td><td></td><td></td><td></td></tr>
        <tr><td><strong>Charlie</strong></td><td>Ethel</td><td></td><td>Carol</td><td></td><td></td></tr>
    </tbody>
</table>

<hr>

Daniel's still out on Friday. Albert rotates out of track Alpha as planned,
and as Farah was soloing yesterday we want to make sure they have a pair today:

<table style="table-layout: fixed; width: 100%">
    <thead>
        <tr><th>Track</th><th>🟢 Day 1</th><th>🟡 Day 2</th><th>🟠 Day 3</th><th>🔴 Day 4</th><th>🔥 Day 5</th></tr>
    </thead>
    <tbody>
        <tr><td><strong>Alpha</strong></td><td>Carol</td><td>Basti</td><td></td><td></td><td></td></tr>
        <tr><td><strong>Bravo</strong></td><td>Albert</td><td></td><td>Farah</td
><td></td><td></td></tr>
        <tr><td><strong>Charlie</strong></td><td></td><td>Ethel</td><td></td><td></td><td></td></tr>
    </tbody>
</table>

<hr>

Despite some planned and unplanned absences, we've got to the end of the week without anyone ending up in "jail"! Every day we've had at least one person stay in each track, to bring a consistent context. Every track has had at least three different people working on it during the week, encouraging shared ownership of the whole codebase and ensuring lots of different ideas are brought into each track. And in terms of building relationships, if we think about who has paired with whom, we've achieved a good balance throughout the team; the only pairings that _haven't_ been made during the week are:

- Albert and Carol;
- Basti and Ethel;
- Daniel and Ethel; and
- Daniel and Farah.

This isn't to say that there will never be times when you want someone to stay on one track of work for five or more days, but that should really be the exception rather than the rule; you can use this heuristic to be intentful about whether or not that should be happening in your current context.

We also use other practices that support working in this way, for example:

- [INVEST] user stories encourage small steps with clear acceptance criteria;
- Test-driven development (TDD) means that any work in flight has some tests to guide you towards the planned implementation; and
- Trunk-based development pushes you towards small commits and frequent integration  (branches are generally only used to store our progress on the remote overnight, so we're not reliant on any single hard drive continuing to work).

This way, even if there was work in flight on a given track yesterday and there's nobody in today who worked on it, you have a high quality user story, failing test(s) to start from and small diff to understand. This keeps the team resilient and able to make progress.

  [CC BY-SA 4.0]: https://creativecommons.org/licenses/by-sa/4.0/
  [Denise Yu]: https://deniseyu.io/
  [introduction to pairing]: {filename}/work/ada-college-pairing.md
  [INVEST]: https://www.pivotaltracker.com/blog/how-to-invest-in-your-user-stories
  [jail]: https://en.wikipedia.org/wiki/Monopoly_(game)#Jail
  [Miro]: https://miro.com/
  [pairing table]: {static}/images/pairing-table.png
  [Parrit]: https://parrit.io/
  [table widget]: https://help.miro.com/hc/en-us/articles/360011986519-Tables
