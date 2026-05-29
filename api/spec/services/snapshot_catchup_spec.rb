require 'date'

RSpec.describe SnapshotCatchup do
  let(:portfolio) { Portfolio.create(name: 'Main') }

  before do
    allow(BackfillService).to receive(:call)
    allow(SnapshotService).to receive(:call)
  end

  def snapshot_on(date)
    PortfolioSnapshot.create(portfolio_id: portfolio.id, date: date,
                             total_value_pln: 1, total_cost_pln: 1, pnl_pln: 0)
  end

  # 2026-05-29 is a Friday; 2026-05-28 Thursday; the weekend is 30–31.
  it 'does nothing when the latest snapshot already covers the last expected weekday' do
    snapshot_on(Date.new(2026, 5, 28)) # Thu — the expected day at Fri 09:00

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(BackfillService).not_to have_received(:call)
    expect(SnapshotService).not_to have_received(:call)
  end

  it 'backfills past days when a weekday snapshot is missing, without snapshotting today before 22:30' do
    snapshot_on(Date.new(2026, 5, 26)) # gap: Wed 27 and Thu 28 missing

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0)) # Fri, before the window

    expect(BackfillService).to have_received(:call)
    expect(SnapshotService).not_to have_received(:call)
  end

  it "also snapshots today once today's 22:30 window has passed" do
    snapshot_on(Date.new(2026, 5, 28))

    described_class.call(now: Time.utc(2026, 5, 29, 23, 0)) # Fri, after the window

    expect(BackfillService).to have_received(:call)
    expect(SnapshotService).to have_received(:call)
  end

  it 'skips the weekend: Saturday expects Friday' do
    snapshot_on(Date.new(2026, 5, 29)) # Fri present

    described_class.call(now: Time.utc(2026, 5, 30, 12, 0)) # Sat

    expect(BackfillService).not_to have_received(:call)
  end

  it 'runs catch-up on first boot when there are no snapshots yet' do
    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(BackfillService).to have_received(:call)
  end
end
