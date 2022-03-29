import * as DOM from "incremental-dom"
import { Wisp } from "./wisp"

type U32 = number

export interface Callback {
  packageName: string,
  functionName: string,
}

// I couldn't resist the name.  It's like WASI but for the DOM.
//
// We use the "Incremental DOM" library for a simple but efficient way
// to update DOM nodes which we can very easily bind to Wisp.
//
export class WASD {
  wisp: Wisp
  callbackOperation: (cb: Callback, data: U32) => void

  elements: Map<U32, HTMLElement>
  callbacks: Map<U32, (data: U32) => void>

  nextElementId = 1
  nextCallbackId = 1

  constructor() {
    this.elements = new Map
    this.callbacks = new Map
  }

  setWisp(wisp: Wisp) {
    this.wisp = wisp
  }

  setCallbackOperation(
    operation: (cb: Callback, data: U32) => void
  ) {
    this.callbackOperation = operation
  }

  exports() {
    return {
      make_callback: (
        pkgptr: U32, pkglen: U32,
        funptr: U32, funlen: U32,
      ) => {
        const packageName = this.wisp.getString(pkgptr, pkglen)
        const functionName = this.wisp.getString(funptr, funlen)

        this.callbacks.set(this.nextCallbackId, (data: U32) => {
          this.callbackOperation({ packageName, functionName }, data)
        })

        return this.nextCallbackId++
      },

      query_selector: (selectorPointer: U32, selectorLength: U32) => {
        let selector = this.wisp.getString(selectorPointer, selectorLength)
        let element = document.querySelector(selector)
        if (element !== null) {
          this.elements.set(this.nextElementId, element as HTMLElement)
          return this.nextElementId++
        } else {
          return 0
        }
      },

      patch: (elementId: U32, callbackId: U32, data: U32) => {
        try {
          let element = this.elements.get(elementId)
          let callback = this.callbacks.get(callbackId)

          queueMicrotask(() => {
            DOM.patch(element, callback, data)
          })

          return 0
        } catch (e) {
          throw e
        }
      },

      open_start: (tagptr: U32, taglen: U32) => {
        let tag = this.wisp.getString(tagptr, taglen)
        DOM.elementOpenStart(tag.toLowerCase())
      },

      open_end: () => {
        DOM.elementOpenEnd()
      },

      attr: (
        attrptr: U32, attrlen: U32, valptr: U32, vallen: U32
      ) => {
        let attr = this.wisp.getString(attrptr, attrlen)
        let val = this.wisp.getString(valptr, vallen)
        DOM.attr(attr.toLowerCase(), val)
      },

      attr_callback: (
        attrptr: U32, attrlen: U32, callbackId: U32
      ) => {
        let attr = this.wisp.getString(attrptr, attrlen)
        let callback = this.callbacks.get(callbackId)
        DOM.attr(attr.toLowerCase(), callback)
      },

      close: (tagptr: U32, taglen: U32) => {
        let tag = this.wisp.getString(tagptr, taglen)
        DOM.elementClose(tag.toLowerCase())
      },

      text: (ptr: U32, len: U32) => {
        let text = this.wisp.getString(ptr, len)
        DOM.text(text)
      },

      on_keydown: (callbackId: U32) => {
        let callback = this.callbacks.get(callbackId)
        window.addEventListener(
          "keydown",
          key => {
            let truth = (x: any) => x ? this.wisp.sys.t : this.wisp.sys.nil
            callback(this.wisp.newv32([
              this.wisp.newv08(key.key),
              truth(key.ctrlKey),
              truth(key.shiftKey),
              truth(key.altKey),
              truth(key.metaKey),
              truth(key.repeat),
            ]))
          },
        )
      },

      prompt: (ptr: U32, len: U32) => {
        let text = this.wisp.getString(ptr, len)
        let result = prompt(text)
        if (result === null)
          return this.wisp.sys.nil
        else
          return this.wisp.newv08(result)
      },

      step: (elementId: U32, direction: U32) => {
        let e = this.elements.get(elementId)
        step(e, direction)
      }
    }
  }
}

function step(e: HTMLElement, direction: number): boolean {
  if (direction === 0 || direction === 1) {
    let forward = direction === 0
    let next = forward ? e.nextElementSibling : e.previousElementSibling
    if (next) {
      if (next.tagName === "DIV") {
        next.insertAdjacentElement(forward ? "afterbegin" : "beforeend", e)
        return true
      } else {
        next.insertAdjacentElement(forward ? "afterend" : "beforebegin", e)
        return true
      }
    } else {
      let up = e.parentElement.closest("div")
      if (up) {
        up.insertAdjacentElement(forward ? "afterend" : "beforebegin", e)
        return true
      }
    }
  } else if (direction === 2) {
    let y = e.offsetTop
    let moved = false
    while (true) {
      if (step(e, 1)) {
        moved = true
        if (e.offsetTop < y)
          break
      } else {
        break
      }
    }
    return moved
  } else if (direction === 3) {
    let y = e.offsetTop
    let moved = false
    while (true) {
      if (step(e, 0)) {
        moved = true
        if (e.offsetTop > y)
          break
      } else {
        break
      }
    }
    return moved
  } else if (direction === 4) {
    if (e.previousElementSibling && e.nextElementSibling) {
      let p = e.previousElementSibling
      p.insertAdjacentElement("beforebegin", e.nextElementSibling)
      e.previousElementSibling.insertAdjacentElement("beforebegin", e)
      return true
    }
  } else if (direction === 5) {
    if (e.nextElementSibling) {
      e.nextElementSibling.remove()
      return true
    }
  } else if (direction == 6) {
    if (e.nextElementSibling) {
      e.parentNode.insertBefore(e.nextElementSibling.cloneNode(true), e.nextElementSibling)
      return true
    }
  }

  return false
}
