
function randInt(min, max) { // min and max included 
    return Math.floor(Math.random() * (max - min + 1) + min)
}

function color(hc) {
    return hc >> 4
}

function initCanvas(board) {
    // You can use either PIXI.WebGLRenderer or PIXI.CanvasRenderer
    let app = new PIXI.Application({
        width: window.innerWidth,
        height: window.innerHeight,
        backgroundAlpha: 0,
        antialias: true,
        // view: document.getElementById("boxes")
    })

    document.getElementById("ROOT").append(app.view)

    const container = new PIXI.Container()
    app.stage.addChild(container)

    //declare all letiables
    let body = document.body
    let currScale = 1
    let maxScale = 10
    let minScale = 0.1
    let offX = 0
    let offY = 0


    let mousedown = false

    let ctx = new PIXI.Graphics()

    for (const id in board.data.objects) {
        const obj = board.data.objects[id]
        console.log(obj)

        const i = 1

        ctx.beginFill(color(obj.theme.bg))
        ctx.lineStyle(obj.font.size / 20 * i, color(obj.theme.st))
        ctx.drawRect(
            obj.position.x * i, obj.position.y * i,
            obj.font.size * i * 2, obj.font.size * i * 2)
    }

    let mainLayer = container
    mainLayer.addChild(ctx)


    //Build object hierarchy
    // graphicLayer.addChild(ctx)
    // mainLayer.addChild(graphicLayer)
    // stage.addChild(mainLayer)

    //Animate via WebAPI
    requestAnimationFrame(animate)

    //Scale mainLayer
    mainLayer.scale.set(1, 1)

    function animate() {
        app.render()
        // Recursive animation request, disabled for performance.
        // requestAnimationFrame(animate)
    }

    window.addEventListener('mousedown', function (e) {
        //Reset clientX and clientY to be used for relative location base panning
        clientX = -1
        clientY = -1
        mousedown = true
    })

    window.addEventListener('mouseup', function (e) {
        mousedown = false
    })

    window.addEventListener('mousemove', function (e) {
        // Check if the mouse button is down to activate panning
        if (mousedown) {

            // If this is the first iteration through then set clientX and clientY to match the inital mouse position
            if (clientX == -1 && clientY == -1) {
                clientX = e.clientX
                clientY = e.clientY
            }

            // Run a relative check of the last two mouse positions to detect which direction to pan on x
            if (e.clientX == clientX) {
                xPos = 0
            } else if (e.clientX < clientX) {
                xPos = -Math.abs(e.clientX - clientX)
            } else if (e.clientX > clientX) {
                xPos = Math.abs(e.clientX - clientX)
            }

            // Run a relative check of the last two mouse positions to detect which direction to pan on y
            if (e.clientY == clientY) {
                yPos = 0
            } else if (e.clientY < clientY) {
                yPos = -Math.abs(e.clientY - clientY)
            } else if (e.clientY > clientY) {
                yPos = Math.abs(clientY - e.clientY)
            }

            // Set the relative positions for comparison in the next frame
            clientX = e.clientX
            clientY = e.clientY

            // Change the main layer zoom offset x and y for use when mouse wheel listeners are fired.
            offX = mainLayer.position.x + xPos
            offY = mainLayer.position.y + yPos

            // Move the main layer based on above calucalations
            mainLayer.position.set(offX, offY)

            // Animate the container
            requestAnimationFrame(animate)
        }
    })

    //Attach cross browser mouse wheel listeners
    body.addEventListener('mousewheel', zoom, false)     // Chrome/Safari/Opera
    body.addEventListener('DOMMouseScroll', zoom, false) // Firefox


    /**
     * Detect the amount of distance the wheel has traveled and normalize it based on browsers.
     * @param  event
     * @return integer
     */
    function wheelDistance(evt) {
        if (!evt) evt = event
        let w = evt.wheelDelta
        let d = evt.detail
        if (d) {
            if (w) return w / d / 40 * d > 0 ? 1 : -1 // Opera
            else return -d / 3              // Firefox         TODO: do not /3 for OS X
        } else return w / 120             // IE/Safari/Chrome TODO: /3 for Chrome OS X
    }

    /**
     * Detect the direction that the scroll wheel moved
     * @param event
     * @return integer
     */
    function wheelDirection(evt) {
        if (!evt) evt = event
        return (evt.detail < 0) ? 1 : (evt.wheelDelta > 0) ? 1 : -1
    }

    /**
     * Zoom into the DisplayObjectContainer that acts as the container
     * @param event
     */
    function zoom(evt) {

        // Find the direction that was scrolled
        let direction = wheelDirection(evt)

        // Find the normalized distance
        let distance = wheelDistance(evt)

        // Set the old scale to be referenced later
        let old_scale = currScale

        // Find the position of the clients mouse
        x = evt.clientX
        y = evt.clientY

        // Manipulate the scale based on direction
        currScale = old_scale + distance * 0.1
        console.log(distance, direction)

        //Check to see that the scale is not outside of the specified bounds
        if (currScale > maxScale) currScale = maxScale
        else if (currScale < minScale) currScale = minScale

        // This is the magic. I didn't write this, but it is what allows the zoom to work.
        offX = (offX - x) * (currScale / old_scale) + x
        offY = (offY - y) * (currScale / old_scale) + y

        //Set the position and scale of the DisplayObjectContainer
        mainLayer.scale.set(currScale, currScale)
        mainLayer.position.set(offX, offY)

        //Animate the container
        requestAnimationFrame(animate)
    }
}

function fetchBoard() {
    fetch("/board.json")
        .then(r => r.json())
        .then(initCanvas)
}

console.log("hey")
fetchBoard()