package main

// Synacor challenge: implement a CPU emulator for fun and learning purpose.
//
// Copyright (C) 2023 A-725-K (Andrea Canepa)
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <https://www.gnu.org/licenses/>.

import (
  "fmt"
  "strconv"
)

const THRESHOLD = 80

type Queue[T any] struct {
  q []T
  size int
}

func NewQueue[T any]() *Queue[T]{
  return &Queue[T]{q: []T{}, size: 0}
}

func (q *Queue[T]) Enqueue(el T) {
  q.q = append(q.q, el)
  q.size++
}

func (q *Queue[T]) Dequeue() T {
  defer func() {
    q.q = q.q[1:]
    q.size--
  }()
  return q.q[0]
}

func (q *Queue[T]) IsEmpty() bool {
  return q.size == 0
}

func atoi(s string) int {
  i, err := strconv.Atoi(s)
  if err != nil {
    panic("Cannot convert a number")
  }
  return i
}

type Step struct {
  value, x, y int
  prevOp string
  path []string
  lvl int
}

func isValid(x, y int) bool {
  return x >= 0 && x <= 3 && y >= 0 && y <= 3
}

func isOperand(s string) bool {
  return s == "+" || s == "-" || s == "*"
}

func findPath(maze [][]string, goal int) (paths [][]string) {
  startX, startY := 0, 3
  endX, endY := 3, 0
  hitStart := false

  q := NewQueue[Step]()
  q.Enqueue(Step{0, startX, startY, "+", []string{"take orb (0,3) [22]"}, 0})
  minLvl := 999

  for !q.IsEmpty() {
    curr := q.Dequeue()

    // fmt.Printf(
    //   "Curr:\t- (%d, %d)\t- value=%d\t- level=%d\n",
    //   curr.x, curr.y,
    //   curr.value,
    //   curr.lvl,
    // )
    
    nextOp := ""
    nextValue := curr.value
    if isOp := isOperand(maze[curr.y][curr.x]); isOp {
      nextOp = maze[curr.y][curr.x]
    } else {
      this := atoi(maze[curr.y][curr.x])
      switch curr.prevOp {
      case "+":
        nextValue += this
      case "-":
        nextValue -= this
      case "*":
        nextValue *= this
      default:
        panic(fmt.Sprintf("Operation not known: %s", curr.prevOp))
      }
      curr.prevOp = ""
    }

    // it is possible to walk on the final tile only once
    if curr.x == endX && curr.y == endY {
      // can open the secret vault
      if nextValue == goal && curr.lvl <= minLvl {
        minLvl = curr.lvl
        fmt.Println(">>>>>>>>>>>", curr)
        paths = append(paths, curr.path)
      }
      // ended up in the final tile with a wrong orb weight, discard this path
      continue
    }

    // if the current level is greater than the min path already found
    // that path won't be the correct one
    if curr.lvl > minLvl {
      continue
    }

    // if the orb is too heavy or too light, I assume there is no solution down
    // that path
    if curr.value > THRESHOLD || curr.value < 0 {
      continue
    }

    // it is possible to walk on start tile only once
    if hitStart && curr.x == startX && curr.y == startY {
      continue
    }
    hitStart = true

    // try to walk east
    if isValid(curr.x+1, curr.y) {
      newPath := make([]string, len(curr.path))
      copy(newPath, curr.path)
      newPath = append(
        newPath,
        fmt.Sprintf(
          "east (%d,%d) [%s] {%d}",
          curr.x+1, curr.y,
          maze[curr.y][curr.x+1],
          nextValue,
        ),
      ) 
      q.Enqueue(Step{nextValue, curr.x+1, curr.y, nextOp, newPath, curr.lvl+1})
    }

    // try to walk west
    if isValid(curr.x-1, curr.y) {
      newPath := make([]string, len(curr.path))
      copy(newPath, curr.path)
      newPath = append(
        newPath,
        fmt.Sprintf(
          "west (%d,%d) [%s] {%d}",
          curr.x-1, curr.y,
          maze[curr.y][curr.x-1],
          nextValue,
        ),
      )
      q.Enqueue(Step{nextValue, curr.x-1, curr.y, nextOp, newPath, curr.lvl+1})
    }

    // try to walk south
    if isValid(curr.x, curr.y+1) {
      newPath := make([]string, len(curr.path))
      copy(newPath, curr.path)
      newPath = append(
        newPath,
        fmt.Sprintf(
          "south (%d,%d) [%s] {%d}",
          curr.x, curr.y+1,
          maze[curr.y+1][curr.x],
          nextValue,
        ),
      )
      q.Enqueue(Step{nextValue, curr.x, curr.y+1, nextOp, newPath, curr.lvl+1})
    }

    // try to walk north
    if isValid(curr.x, curr.y-1) {
      newPath := make([]string, len(curr.path))
      copy(newPath, curr.path)
      newPath = append(
        newPath,
        fmt.Sprintf(
          "north (%d,%d) [%s] {%d}",
          curr.x, curr.y-1,
          maze[curr.y-1][curr.x],
          nextValue,
        ),
      )
      q.Enqueue(Step{nextValue, curr.x, curr.y-1, nextOp, newPath, curr.lvl+1})
    }
  }

  return
}

func main() {
  goal := 30
  maze := [][]string{
    {"*", "8", "-", "1"},
    {"4", "*", "11", "*"},
    {"+", "4", "-", "18"},
    {"22", "-", "9", "*"},
  }

  for y := 0; y < 4; y++ {
     for x := 0; x < 4; x++ {
       fmt.Printf("[%2s]", maze[y][x])
     }
     fmt.Println()
  }

  ps := findPath(maze, goal)
  for i, p := range ps {
    fmt.Printf("[%d] Path of lenght %d:\n", i, len(p)-1)
    for _, s := range p {
      fmt.Println(" ", s)
    }
    fmt.Println()
  }
}
