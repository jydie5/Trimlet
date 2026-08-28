using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class EditListTests
{
    [TestMethod]
    public void AddMoveUpdateAndRemovePreserveStableIdentityAndName()
    {
        var first = Segment("Intro", 1, 2);
        var second = Segment("Main", 4, 6);
        var list = new EditList()
            .Add(first, MediaTimestamp.FromSeconds(10))
            .Add(second, MediaTimestamp.FromSeconds(10));

        list = list.Move(second.Id, 0);
        Assert.AreEqual(second.Id, list.Segments[0].Id);

        list = list.Update(second.WithRange(Range(4.5, 6.5)), MediaTimestamp.FromSeconds(10));
        Assert.AreEqual("Main", list.Segments[0].Name);
        Assert.AreEqual(2, list.Segments[0].DurationSeconds, 0.000001);

        list = list.Remove(first.Id);
        Assert.HasCount(1, list.Segments);
    }

    [TestMethod]
    public void OverlapIsRejectedRegardlessOfOutputOrder()
    {
        var list = new EditList().Add(Segment("First", 1, 3));
        Assert.Throws<InvalidDataException>(() => list.Add(Segment("Overlap", 2, 4)));
    }

    [TestMethod]
    public void HalfOpenAdjacentRangesDoNotOverlap()
    {
        var list = new EditList()
            .Add(Segment("First", 1, 3))
            .Add(Segment("Second", 3, 4));

        Assert.HasCount(2, list.Segments);
        Assert.AreEqual(3, list.TotalDurationSeconds, 0.000001);
    }

    private static EditSegment Segment(string name, double @in, double @out) =>
        new(Guid.NewGuid(), name, Range(@in, @out));

    private static TrimRange Range(double @in, double @out) =>
        new(MediaTimestamp.FromSeconds(@in), MediaTimestamp.FromSeconds(@out));
}
