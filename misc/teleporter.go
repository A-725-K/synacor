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

import "fmt"

const MOD = 32768
const GOROUTINES_NUM = 8

// FIRST TRY: INFEASIBLE! THIS FUNCTION NEED TO BE OPTIMIZED
// func Ack(r0, r1 *int, r7 int) {
//   if *r0 != 0 {
//     if *r1 != 0 {
//       r0Tmp := *r0
//       *r1 = (*r1 - 1) % MOD
//       Ack(r0, r1, r7)
//       *r1 = *r0
//       *r0 = (r0Tmp - 1) % MOD
//       Ack(r0, r1, r7)
//       return
//     }
//
//     *r0 = (*r0 - 1) % MOD
//     *r1 = r7
//     Ack(r0, r1, r7)
//     return
//   }
//
//   *r0 = (*r1 + 1) % MOD
//   return
// }

// SECOND TRY: STILL NOT GOOD! BUT VERY NICE READ: https://shorturl.at/iuTY5
// func GrossmanZeitmanAck(r0, r1, r7 int) int {
//   next, goal := []int{}, []int{}
//   for r := 0; r <= r0; r++ {
//     next = append(next, 0)
//     goal = append(goal, r7)
//   }
//   goal[r0] = -r7
//
//   i := 0
//   value := 0
//   for {
//     value = (next[0]+1)%MOD
//     transferring := true
//     i = 0
//     for transferring {
//       if next[i] == goal[i] {
//         goal[i] = value
//       } else {
//         transferring = false
//       }
//       next[i] = (next[i]+1)%MOD
//       i = (i+1)%MOD
//     }
//
//     if next[r0] == r1+1 {
//       break
//     }
//   }
//
//   return value
// }

func toKey(a, b int) string {
  return fmt.Sprintf("%d:%d", a, b)
}

// THIRD TRY: MEMOIZATION IS THE KEY!!!
func memoAck(r0, r1, r7 int, memo *map[string]int) int {
  if res, ok := (*memo)[toKey(r0, r1)]; ok {
    return res
  }

  var res int
  if r0 == 0 {
    res = (r1+1) % MOD
    (*memo)[toKey(r0, r1)] = res
    return res
  }

  if r1 == 0 {
    res = memoAck((r0-1)%MOD, r7, r7, memo)
    (*memo)[toKey((r0-1)%MOD, r7)] = res
    return res
  }

  r0Tmp := r0
  r0 = memoAck(r0, (r1-1)%MOD, r7, memo)
  (*memo)[toKey(r0Tmp, (r1-1)%MOD)] = r0
  res = memoAck((r0Tmp-1)%MOD, r0, r7, memo)
  (*memo)[toKey((r0Tmp-1)%MOD, r0)] = res

  return res
}

func rangeMemoAck(id, start, end int, resCh chan int, stopCh chan struct{}) {
  for r7 := start; r7 < end; r7++ {
    select {
    case <-stopCh:
      return
    default:
    }

    if r7%500 == 0 {
      fmt.Printf("[%d] Testing %d...\n", id, r7)
    }

    memo := make(map[string]int)
    res := memoAck(4, 1, r7, &memo)

    if res == 6 {
      fmt.Println("Result found in goroutine", id)
      resCh<-r7
    }
  }
}

func main() {
  resCh := make(chan int)
  stopCh := make(chan struct{})
  for i := 0; i < GOROUTINES_NUM; i++ {
    start, end := MOD/GOROUTINES_NUM*i, MOD/GOROUTINES_NUM*(i+1)
    go rangeMemoAck(i, start, end, resCh, stopCh)
  }

  select {
  case res := <-resCh:
      // 25734
      fmt.Println(">>>", res)
      close(stopCh)
  }
}

