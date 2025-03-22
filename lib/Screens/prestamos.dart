import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgregarPrestamo extends StatefulWidget {
  final String clienteId;

  AgregarPrestamo({required this.clienteId});

  @override
  _AgregarPrestamoState createState() => _AgregarPrestamoState();
}

class _AgregarPrestamoState extends State<AgregarPrestamo> {
  final _formularioKey = GlobalKey<FormState>();
  final _controladorMonto = TextEditingController();
  final _controladorTasaInteres = TextEditingController();
  final _controladorCuotas = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar Préstamo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formularioKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _controladorMonto,
                  decoration: InputDecoration(
                    labelText: 'Monto del Préstamo',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el monto';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _controladorTasaInteres,
                  decoration: InputDecoration(
                    labelText: 'Tasa de Interés (%)',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese la tasa de interés';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _controladorCuotas,
                  decoration: InputDecoration(
                    labelText: 'Número de Cuotas',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el número de cuotas';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                  if (_formularioKey.currentState!.validate()) {
                    double monto = double.parse(_controladorMonto.text);
                    double tasaInteres = double.parse(_controladorTasaInteres.text);
                    int plazo = int.parse(_controladorCuotas.text);

                    var prestamoRef = await FirebaseFirestore.instance.collection('prestamos').add({
                      'clienteId': widget.clienteId,
                      'monto': monto,
                      'tasaInteres': tasaInteres,
                      'plazo': plazo,
                      'fechaCreacion': DateTime.now(),
                      'saldo': monto,
                      'estado': 'Activo',
                    });

                    for (int i = 1; i <= plazo; i++) {
                      await FirebaseFirestore.instance.collection('prestamos').doc(prestamoRef.id).collection('cuotas').add({
                        'numero': i,
                        'estado': 'Pendiente',
                      });
                    }

                    Navigator.pop(context);
                  }
                },
                  child: Text('Guardar Préstamo', style: TextStyle(color: Colors.blueAccent)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}