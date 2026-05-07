// Shared CDC MMWR epiweek utilities for StudyStats site.
// MMWR week 1 = the week (Sun–Sat) that contains Jan 4 (i.e., has ≥4 days in the new year).
(function (global) {
  function getEpiWeek(date) {
    var d = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    // Sunday that starts the week containing `d`.
    function weekStartSunday(x) {
      var s = new Date(x);
      s.setDate(x.getDate() - x.getDay());
      return s;
    }

    // Compute MMWR week-1 start for a given calendar year:
    // it's the Sunday on/before Jan 4 of that year.
    function mmwrWeek1Start(year) {
      var jan4 = new Date(year, 0, 4);
      return weekStartSunday(jan4);
    }

    var thisWeekStart = weekStartSunday(d);
    var year = d.getFullYear();
    var w1 = mmwrWeek1Start(year);

    // If our week starts before this year's week 1, we're in the previous MMWR year.
    if (thisWeekStart < w1) {
      year -= 1;
      w1 = mmwrWeek1Start(year);
    } else {
      // If we're at or past next year's week 1, roll forward.
      var nextW1 = mmwrWeek1Start(year + 1);
      if (thisWeekStart >= nextW1) {
        year += 1;
        w1 = nextW1;
      }
    }

    var diffDays = Math.round((thisWeekStart - w1) / (1000 * 60 * 60 * 24));
    var epiWeek = Math.floor(diffDays / 7) + 1;

    var weekEnd = new Date(thisWeekStart);
    weekEnd.setDate(thisWeekStart.getDate() + 6);

    return { epiWeek: epiWeek, epiYear: year, weekStart: thisWeekStart, weekEnd: weekEnd };
  }

  global.StudyStats = global.StudyStats || {};
  global.StudyStats.getEpiWeek = getEpiWeek;
})(window);
