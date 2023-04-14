import { useState } from "react";
import { Database } from "@tableland/sdk";
import { Inter } from 'next/font/google'

interface game {
  created: number,
  creator: string, 
  id: number, 
  letters: number, 
  remaining: number, 
  winner: string, 
  word: string, 
}

interface table {
  results: game[]
}

const inter = Inter({ subsets: ['latin'] })
const db = new Database();

const lines = [
    ["____________", "|          |", "|", "|", "|", "|", "|", "|"],
    ["____________", "|          |", "|          0", "|", "|", "|", "|", "|"],
    [
      "____________",
      "|          |",
      "|          0",
      "|          |",
      "|          |",
      "|",
      "|",
      "|",
    ],
    [
      "____________",
      "|          |",
      "|          0",
      "|         /|",
      "|          |",
      "|",
      "|",
      "|",
    ],
    [
      "____________",
      "|          |",
      "|          0",
      "|         /|\\",
      "|          |",
      "|",
      "|",
      "|",
    ],
    [
      "____________",
      "|          |",
      "|          0",
      "|         /|\\",
      "|          |",
      "|         /",
      "|",
      "|",
    ],
    [
      "____________",
      "|          |",
      "|          0",
      "|         /|\\",
      "|          |",
      "|         / \\",
      "|",
      "|",
    ],
];

async function getGame(): Promise<game[]> {
  const urlParams = new URLSearchParams(window.location.search);
  const table = urlParams.get("table") || "game_store_80001_4440";
  const tokenId =  urlParams.get("token") || "1";
  const root = `SELECT * FROM ${table}`;
  const where = `WHERE id = '${tokenId}'`;
  const statement = `${root} ${where}`;
  const games:table = await db.prepare(statement).all();
  return games.results;
}

export default function Home() {
  const [level, setLevel] = useState(0);
  const [dead, setDead] = useState(false);
  const [won, setWon] = useState(false);
  const [word, setWord] = useState("_");
  getGame().then((data) => {
    if (data.length === 0) return;
    setWord(data[0].word.split("").join(" "));
    setWon(data[0].winner != null);
    setDead(data[0].remaining == 0);
    setLevel(6 - data[0].remaining);
    if (won) {
      document.body.style.backgroundColor = "green";
    } else if (data[0].remaining == 0) {
      document.body.style.backgroundColor = "black";
    } else {
      document.body.style.backgroundColor = "white";
    }
  })

  return (
    <div className={`nft ${won && "wonb"} ${dead && "lostb"}`}>
      {lines[level].map((line, i) => (
        <div className={`line ${won && "wonf"} ${dead && "lostf"}`} key={i}>{line}</div>
      ))}
      <div className={`word ${won && "wonf"} ${dead && "lostf"}`}>{word}</div>
    </div>
  );
}
