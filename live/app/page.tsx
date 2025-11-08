import TimingTable from "@/components/TimingTable";

export default function Home() {
  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-gray-900 border-b border-gray-800">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <h1 className="text-2xl font-bold text-white">FIA WEC</h1>
              <span className="text-gray-400">|</span>
              <h2 className="text-xl text-gray-300">Live Timing</h2>
            </div>
            <div className="flex items-center space-x-6">
              <div className="text-sm text-gray-400">
                <span className="text-white font-semibold">1812km of Qatar</span>
              </div>
              <div className="text-sm text-gray-400">
                Season <span className="text-white">2025</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-6">
        <div className="bg-gray-900 rounded-lg overflow-hidden shadow-xl">
          <TimingTable raceId="qatar-2025" />
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-gray-900 border-t border-gray-800 mt-12">
        <div className="container mx-auto px-4 py-6 text-center text-sm text-gray-500">
          <p>WEC Live Timing - Mock Application</p>
          <p className="mt-1">Data simulated for demonstration purposes</p>
        </div>
      </footer>
    </div>
  );
}
