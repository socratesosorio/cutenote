import { useEffect, useRef, useState } from "react";
import logo from "/assets/openai-logomark.svg";
import TranscriptLog from "./TranscriptLog";
import TranscriptionControls from "./TranscriptionControls";
import Sidebar from "./Sidebar";

export default function App() {
  // UI only for transcript feed now

  return (
    <>
      <nav className="absolute top-0 left-0 right-0 h-16 flex items-center">
        <div className="flex items-center gap-4 w-full m-4 pb-2 border-0 border-b border-solid border-gray-200">
          <img style={{ width: "24px" }} src={logo} />
          <h1>Your Transcription Console 💜</h1>
        </div>
      </nav>
      <main className="absolute top-16 left-0 right-0 bottom-0">
        <section className="absolute top-0 left-0 right-[380px] bottom-0 flex">
          <section className="absolute top-0 left-0 right-0 bottom-32 px-4 overflow-y-auto">
            <TranscriptLog />
          </section>
          <section className="absolute h-32 left-0 right-0 bottom-0 p-4">
            <TranscriptionControls />
          </section>
        </section>
        <Sidebar />
      </main>
    </>
  );
}
